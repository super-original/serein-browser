import Foundation
import SereinCore

@MainActor enum DownloadIdentityVerification {
    static func run(root:URL,session:BrowserSession)->[RuntimeVerification.Result] {
        var results:[RuntimeVerification.Result]=[]
        func check(_ name:String,_ value:Bool,_ detail:String="") {results.append(.init(name:"download-identity-"+name,passed:value,detail:detail))}
        do {
            let directory=root.appendingPathComponent("download-identity-probe")
            try PrivateFileStore.prepareDirectory(directory)
            let legacy=DownloadRecord(name:"Legacy normal",phase:.complete)
            try PrivateFileStore.write(DownloadRecord.encodedHistory([legacy]),to:directory.appendingPathComponent("downloads.json"))
            let store=DownloadStore(root:directory)
            let migrated=try DownloadHistory.decode(Data(contentsOf:store.file))
            check("legacy-migration-persisted",!migrated.migrated && store.items.first?.record.browserIdentifier==1 && migrated.history.records.first?.id==legacy.id)
            let privateItem=DownloadItem(record:DownloadRecord(name:"Private sentinel",privateWindowID:UUID()),store:store)
            store.items.append(privateItem)
            let privateSave=store.save()
            let normalOnly=try DownloadHistory.decode(Data(contentsOf:store.file)).history
            check("private-does-not-consume-identifier",privateSave && privateItem.record.browserIdentifier==nil && normalOnly.records.count==1 && normalOnly.nextIdentifier==2)
            store.clearFinished(in:session)
            let reopened=DownloadStore(root:directory)
            let next=DownloadItem(record:DownloadRecord(name:"Next normal",phase:.complete),store:reopened)
            reopened.items.append(next)
            check("clear-reopen-does-not-reuse",reopened.save() && next.record.browserIdentifier==2)

            let failureDirectory=directory.appendingPathComponent("write-failure")
            try PrivateFileStore.prepareDirectory(failureDirectory)
            let failureStore=DownloadStore(root:failureDirectory)
            let pending=DownloadItem(record:DownloadRecord(phase:.complete),store:failureStore)
            failureStore.items=[pending]
            try FileManager.default.createDirectory(at:failureStore.file,withIntermediateDirectories:false)
            check("failed-write-does-not-publish-identifier",!failureStore.save() && pending.record.browserIdentifier==nil)
            try FileManager.default.removeItem(at:failureStore.file)
            check("retry-publishes-durable-identifier",failureStore.save() && pending.record.browserIdentifier==1 && DownloadStore(root:failureDirectory).items.first?.record.browserIdentifier==1)

            let damagedDirectory=directory.appendingPathComponent("unsupported-history")
            try PrivateFileStore.prepareDirectory(damagedDirectory)
            let damaged=Data("{\"version\":99,\"nextIdentifier\":1,\"records\":[]}".utf8)
            let damagedFile=damagedDirectory.appendingPathComponent("downloads.json")
            try PrivateFileStore.write(damaged,to:damagedFile)
            let unavailable=DownloadStore(root:damagedDirectory)
            check("unknown-history-preserved",unavailable.error != nil && !unavailable.save() && (try? Data(contentsOf:damagedFile))==damaged)
        } catch {check("setup",false,error.localizedDescription)}
        return results
    }
}
