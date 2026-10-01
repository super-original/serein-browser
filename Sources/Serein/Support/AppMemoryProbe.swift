import Foundation
import Darwin

/// Opt-in fixture diagnostics for this process only; no task ports for other apps.
/// Keep physical footprint separate from the attributed subprocess RSS report.
@MainActor enum AppMemoryProbe {
    private struct Sample:Codable {
        let stage:String
        let monotonicSeconds:Double
        let kernelStatus:Int32
        let residentBytes:UInt64?
        let physicalFootprintBytes:UInt64?
    }
    private static var samples:[Sample]=[]
    @discardableResult static func record(_ stage:String)->Bool {
        let args=ProcessInfo.processInfo.arguments
        guard args.contains("--integration-test") || args.contains("--extension-origin-probe"),
              let index=args.firstIndex(of:"--test-root"),args.indices.contains(index+1),samples.count<256 else{return false}
        var info=task_vm_info_data_t()
        var count=mach_msg_type_number_t(MemoryLayout<task_vm_info_data_t>.size/MemoryLayout<integer_t>.size)
        let status=withUnsafeMutablePointer(to:&info) {pointer in
            pointer.withMemoryRebound(to:integer_t.self,capacity:Int(count)) {buffer in
                task_info(mach_task_self_,task_flavor_t(TASK_VM_INFO),buffer,&count)
            }
        }
        let footprintEnd=(MemoryLayout<task_vm_info_data_t>.offset(of:\.phys_footprint) ?? Int.max-MemoryLayout<UInt64>.size)+MemoryLayout<UInt64>.size
        let available=status==KERN_SUCCESS && Int(count)*MemoryLayout<integer_t>.size>=footprintEnd
        samples.append(Sample(stage:stage,monotonicSeconds:ProcessInfo.processInfo.systemUptime,kernelStatus:status,
                              residentBytes:available ? info.resident_size : nil,physicalFootprintBytes:available ? info.phys_footprint : nil))
        do {
            let file=URL(fileURLWithPath:args[index+1],isDirectory:true).appendingPathComponent("app-memory-stages.json")
            try JSONEncoder().encode(samples).write(to:file,options:.atomic)
        } catch {return false}
        return available && info.resident_size>0 && info.phys_footprint>0
    }
}
