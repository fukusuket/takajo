proc splitCsvTimeline(makeMultiline: bool = false, outputDir: string = "output", quiet: bool = false, timeline: string) =
    let startTime = epochTime()
    if not quiet:
        styledEcho(fgGreen, outputLogo())

    echo "Loading the CSV file. Please wait."
    let totalLines = countLinesInTimeline(timeline)
    echo "Total lines: ", totalLines
    echo ""
    echo "Splitting the Hayabusa CSV timeline into separate timelines according to the computer name. Please wait."

    if not dirExists(outputDir):
        echo ""
        echo "The directory '" & outputDir & "' does not exist so will be created."
        createDir(outputDir)
    echo ""

    var
        inputFile = open(timeline, FileMode.fmRead)
        line = ""
        filenameSequence: seq[string] = @[]
        filesTable = initTable[string, File]()
        bar = newProgressBar(total = totalLines)
        lineCount = 0
        updateInterval = max(totalLines div 500, 1)  # Update about every .2% of lines, but at least once per line
    bar.start()

    # Read in the CSV header
    let csvHeader = inputFile.readLine()
    while inputFile.endOfFile == false:
        inc(lineCount)
        if lineCount mod updateInterval == 0:  # Update about every .2% of lines
            bar.set(lineCount)
        updateInterval = max(totalLines div 100, 1)  # Update about every .2% of lines, but at least once per line
        var currentLine = inputFile.readLine()
        let splitFields = currentLine.split(',')
        var computerName = splitFields[1]
        computerName = computerName[1 .. computerName.len - 2] # Remove surrounding double quotes

        # If it is the first time we see this computer name, then record it in a str sequence, create a file,
        # write the CSV headers and current row.
        if not filesTable.hasKey(computerName):
            let filename = outputDir & "/" & computerName & "-HayabusaResults.csv"
            filenameSequence.add(filename)
            var outputFile = open(filename, fmWrite)
            filesTable[computerName] = outputFile
            outputFile.write(csvHeader)
            outputFile.write("\p")
            flushFile(outputFile)  # Flush buffer after writing to file

        # Use the file from the table and write the line.
        var outputFile = filesTable[computerName]
        if makeMultiline == true:
            currentLine = currentLine.replace("¦", "\n")
            outputFile.write(currentLine)
        else:
            outputFile.write(currentLine)
        outputFile.write("\p")
        flushFile(outputFile)
    bar.finish()

    # Close all opened files
    for file in filesTable.values:
        close(file)

    close(inputFile)

    echo ""
    for fn in filenameSequence:
        let fileSize = getFileSize(fn)
        echo "Created the file: " & fn & " (" & formatFileSize(fileSize) & ")"

    echo ""

    let endTime = epochTime()
    let elapsedTime2 = int(endTime - startTime)
    let hours = elapsedTime2 div 3600
    let minutes = (elapsedTime2 mod 3600) div 60
    let seconds = elapsedTime2 mod 60
    echo "Elapsed time: ", $hours & " hours, " & $minutes & " minutes, " & $seconds & " seconds"
    echo ""