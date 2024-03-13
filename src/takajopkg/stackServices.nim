type
  StackServicesCmd* = ref object of AbstractCmd
    level* :string
    header* = @["ServiceName", "Path"]
    stack* = initTable[string, StackRecord]()
    ignoreSystem:bool
    ignoreSecurity:bool

method eventFilter*(self: StackServicesCmd, x: HayabusaJson):bool =
    return (x.EventID == 7045 and not self.ignoreSystem and x.Channel == "Sys") or (x.EventID == 4697 and not self.ignoreSecurity and x.Channel == "Sec")

method eventProcess*(self: StackServicesCmd, x: HayabusaJson)=
    let getStackKey = proc(x: HayabusaJson): (string, seq[string]) =
        let svc = x.Details["Svc"].getStr("N/A")
        let pat = x.Details["Path"].getStr("N/A")
        let stackKey = svc & " -> " & pat
        return (stackKey, @[svc, pat])
    let (stackKey, otherColumn) = getStackKey(x)
    stackResult(stackKey, self.stack, self.level, x, otherColumn=otherColumn)

method resultOutput*(self: StackServicesCmd)=
    outputResult(self.output, self.name, self.stack, self.header)

proc stackServices(level: string = "informational", ignoreSystem: bool = false, ignoreSecurity: bool = false,output: string = "", quiet: bool = false, timeline: string) =
    checkArgs(quiet, timeline, level)
    let cmd = StackServicesCmd(
                level: level,
                timeline: timeline,
                output: output,
                name: "Services",
                msg: "service names and paths from System 7045 and Security 4697 events",
                ignoreSystem: ignoreSystem,
                ignoreSecurity: ignoreSecurity)
    cmd.analyzeJSONLFile()