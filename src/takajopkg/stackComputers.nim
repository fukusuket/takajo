type
  StackComputersCmd* = ref object of AbstractCmd
    level* :string
    header* = @[""]
    stack* = initTable[string, StackRecord]()
    sourceComputers:bool

method eventFilter*(self: StackComputersCmd, x: HayabusaJson):bool =
    return true

method eventProcess*(self: StackComputersCmd, x: HayabusaJson)=
    let getStackKey = proc(x: HayabusaJson): (string, seq[string]) =
        var stackKey = x.Computer
        if self.sourceComputers:
            stackKey = getJsonValue(x.Details, @["SrcComp"])
        return (stackKey, @[""])
    let (stackKey, otherColumn) = getStackKey(x)
    stackResult(stackKey, self.stack, self.level, x)

method resultOutput*(self: StackComputersCmd)=
    outputResult(self.output, self.name, self.stack, isMinColumns=true)

proc stackComputers(level: string = "informational", sourceComputers: bool = false, output: string = "", quiet: bool = false, timeline: string) =
    let startTime = epochTime()
    checkArgs(quiet, timeline, level)
    let cmd = StackComputersCmd(level:level, timeline:timeline, output:output, name:"Computers", msg:"the Computer (default) or SrcComp fields as well as show alert information", sourceComputers:sourceComputers)
    cmd.analyzeJSONLFile()
    outputElapsedTime(startTime)