import Foundation

extension StartupConfiguration {

    public func generateBordersRC() -> GeneratedFile.Outcome {
        let file = Self.bordersrc
        let kept = file.preservedRegions()
        let extra =
            kept["extra"].map {
                "\n\(GeneratedFile.beginKeep) extra\n\($0)\n\(GeneratedFile.endKeep)\n"
            } ?? """

                \(GeneratedFile.beginKeep) extra
                \(GeneratedFile.endKeep)

                """

        let content = Self.header + extra + "exec \"$HOME/.local/bin/macarchy\" startup borders\n"
        return file.write(content, reason: "borders startup changed")
    }
}
