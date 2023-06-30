# Todo: add more info useful for triage, trusted_verdict, signature info, sandbox results etc...
# https://blog.virustotal.com/2021/08/introducing-known-distributors.html
proc vtHashLookup(apiKey: string, hashList: string, jsonOutput: string = "", output: string = "", rateLimit: int = 4, quiet: bool = false) =
    let startTime = epochTime()
    if not quiet:
        styledEcho(fgGreen, outputLogo())

    if not fileExists(hashList):
        echo "The file " & hashList & " does not exist."
        return

    let file = open(hashList)

    # Read each line into a sequence.
    var lines = newSeq[string]()
    for line in file.lines:
        lines.add(line)
    file.close()

    echo "Loaded hashes: ", len(lines)
    echo "Rate limit per minute: ", rateLimit
    echo ""

    let
        timePerHash = 60.0 / float(rateLimit) # time taken to process one hash
        estimatedTimeInSeconds = float(len(lines)) * timePerHash
        estimatedHours = int(estimatedTimeInSeconds) div 3600
        estimatedMinutes = (int(estimatedTimeInSeconds) mod 3600) div 60
        estimatedSeconds = int(estimatedTimeInSeconds) mod 60
    echo "Estimated time: ", $estimatedHours & " hours, " & $estimatedMinutes & " minutes, " & $estimatedSeconds & " seconds"
    echo ""

    let client = newHttpClient()
    client.headers = newHttpHeaders({ "x-apikey": apiKey })

    var
        totalMaliciousHashCount = 0
        bar = newProgressBar(total = len(lines))
        seqOfResultsTables: seq[TableRef[string, string]]
        jsonResponses: seq[JsonNode]  # Declare sequence to store Json responses

    bar.start()

    for hash in lines:
        bar.increment()
        let response = client.request("https://www.virustotal.com/api/v3/files/" & hash, httpMethod = HttpGet)
        var singleResultTable = newTable[string, string]()
        singleResultTable["Hash"] = hash
        singleResultTable["Link"] = "https://www.virustotal.com/gui/file/" & hash
        if response.status == $Http200:
            singleResultTable["Response"] = "200"
            let jsonResponse = parseJson(response.body)
            jsonResponses.add(jsonResponse)
            # Creation Date
            try:
                let creationDateInt = jsonResponse["data"]["attributes"]["creation_date"].getInt()
                let epochCreationDate = fromUnix(creationDateInt).utc
                singleResultTable["CreationDate"] = epochCreationDate.format("yyyy-MM-dd HH:mm:ss")
            except KeyError:
                singleResultTable["CreationDate"] = "Unknown"
            # First In The Wild Date
            try:
                let firstITWDateInt = jsonResponse["data"]["attributes"]["first_seen_itw_date"].getInt()
                let epochFirstITWDate = fromUnix(firstITWDateInt).utc
                singleResultTable["FirstInTheWildDate"] = epochFirstITWDate.format("yyyy-MM-dd HH:mm:ss")
            except KeyError:
                singleResultTable["FirstInTheWildDate"] = "Unknown"
            # First Submission
            try:
                let firstSubmissionDateInt = jsonResponse["data"]["attributes"]["first_submission_date"].getInt()
                let epochFirstSubmissionDate = fromUnix(firstSubmissionDateInt).utc
                singleResultTable["FirstSubmissionDate"] = epochFirstSubmissionDate.format("yyyy-MM-dd HH:mm:ss")
            except KeyError:
                singleResultTable["FirstSubmissionDate"] = "Unknown"
            # Last Submission
            try:
                let lastSubmissionDateInt = jsonResponse["data"]["attributes"]["last_submission_date"].getInt()
                let epochLastSubmissionDate = fromUnix(lastSubmissionDateInt).utc
                singleResultTable["LastSubmissionDate"] = epochLastSubmissionDate.format("yyyy-MM-dd HH:mm:ss")
            except KeyError:
                singleResultTable["LastSubmissionDate"] = "Unknown"
            singleResultTable["MaliciousCount"] = $jsonResponse["data"]["attributes"]["last_analysis_stats"]["malicious"].getInt()
            singleResultTable["HarmlessCount"] = $jsonResponse["data"]["attributes"]["last_analysis_stats"]["harmless"].getInt()
            singleResultTable["SuspiciousCount"] = $jsonResponse["data"]["attributes"]["last_analysis_stats"]["suspicious"].getInt()
            # If it was found to be malicious
            if parseInt(singleResultTable["MaliciousCount"]) > 0:
                inc totalMaliciousHashCount
                echo "\pFound malicious hash: " & hash & " (Malicious count: " & singleResultTable["MaliciousCount"] & " )"
        elif response.status == $Http404:
            echo "\pHash not found: ", hash
            singleResultTable["Response"] = "404"
        else:
            echo "\pUnknown error: ", response.status, " - " & hash
            singleResultTable["Response"] = response.status

        seqOfResultsTables.add(singleResultTable)
        # Sleep to respect the rate limit.
        sleep(int(timePerHash * 1000)) # Convert to milliseconds.

    bar.finish()
    echo ""
    echo "Finished querying hashes"
    echo "Malicious hashes found: ", totalMaliciousHashCount
    # Print elapsed time

    # If saving to a file
    if output != "":
        var outputFile = open(output, fmWrite)
        let header = ["Hash", "Response", "FirstInTheWildDate", "FirstSubmissionDate", "LastSubmissionDate", "MaliciousCount", "HarmlessCount", "SuspiciousCount", "Link"]

        ## Write CSV header
        for h in header:
            outputFile.write(h & ",")
        outputFile.write("\p")

        ## Write contents
        for table in seqOfResultsTables:
            for key in header:
                if table.hasKey(key):
                    outputFile.write(escapeCsvField(table[key]) & ",")
                else:
                    outputFile.write(",")
            outputFile.write("\p")
        let fileSize = getFileSize(output)
        outputFile.close()

        echo "Saved CSV results to " & output & " (" & formatFileSize(fileSize) & ")"

    # After the for loop, check if jsonOutput is not blank and then write the JSON responses to a file
    if jsonOutput != "":
        var jsonOutputFile = open(jsonOutput, fmWrite)
        let jsonArray = newJArray() # create empty JSON array
        for jsonResponse in jsonResponses: # iterate over jsonResponse sequence
            jsonArray.add(jsonResponse) # add each jsonResponse to jsonArray
        jsonOutputFile.write(jsonArray.pretty)
        jsonOutputFile.close()
        let fileSize = getFileSize(jsonOutput)
        echo "Saved JSON responses to " & jsonOutput & " (" & formatFileSize(fileSize) & ")"

    # Print elapsed time
    echo ""
    let endTime = epochTime()
    let elapsedTime = int(endTime - startTime)
    let hours = elapsedTime div 3600
    let minutes = (elapsedTime mod 3600) div 60
    let seconds = elapsedTime mod 60
    echo "Elapsed time: ", $hours & " hours, " & $minutes & " minutes, " & $seconds & " seconds"
    echo ""