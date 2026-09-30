import Foundation

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
        try data.write(to:file,options:.atomic)
        try FileManager.default.setAttributes([.posixPermissions:0o600],ofItemAtPath:file.path)
    }
}
