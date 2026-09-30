import Foundation
import Darwin

/// Files beneath Serein's own application-support directories, never downloads
/// or arbitrary user-selected folders. Atomic temporaries stay inside a private
/// parent even before the final record's permissions are set.
public enum PrivateFileStore {
    public static func prepareDirectory(_ directory:URL) throws {
        try FileManager.default.createDirectory(at:directory,withIntermediateDirectories:true,attributes:[.posixPermissions:0o700])
        try FileManager.default.setAttributes([.posixPermissions:0o700],ofItemAtPath:directory.path)
    }
    public static func write(_ data:Data,to file:URL) throws {
        try prepareDirectory(file.deletingLastPathComponent())
        let temporary=file.deletingLastPathComponent().appendingPathComponent(".serein-write-"+UUID().uuidString)
        let descriptor=open(temporary.path,O_WRONLY | O_CREAT | O_EXCL | O_NOFOLLOW,0o600)
        guard descriptor>=0 else{throw NSError(domain:NSPOSIXErrorDomain,code:Int(errno))}
        defer {try? FileManager.default.removeItem(at:temporary)}
        let handle=FileHandle(fileDescriptor:descriptor,closeOnDealloc:true)
        do {
            guard fchmod(descriptor,0o600)==0 else{throw NSError(domain:NSPOSIXErrorDomain,code:Int(errno))}
            try handle.write(contentsOf:data);try handle.close()
        }
        catch {try? handle.close();throw error}
        // Permissions are final before atomic publication. No fallible work
        // follows the commit point, which update rollback relies on.
        guard rename(temporary.path,file.path)==0 else{throw NSError(domain:NSPOSIXErrorDomain,code:Int(errno))}
    }
}
