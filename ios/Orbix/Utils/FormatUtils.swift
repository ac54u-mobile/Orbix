import Foundation

func formatSpeed(_ speed: Int64) -> String {
    let kb: Int64 = 1024
    let mb = kb * 1024
    let gb = mb * 1024
    if speed >= gb { return String(format: "%.1f GB/s", Double(speed) / Double(gb)) }
    if speed >= mb { return String(format: "%.1f MB/s", Double(speed) / Double(mb)) }
    if speed >= kb { return String(format: "%.1f KB/s", Double(speed) / Double(kb)) }
    return "\(speed) B/s"
}

func formatBytes(_ bytes: Int64) -> String {
    let kb: Int64 = 1024
    let mb = kb * 1024
    let gb = mb * 1024
    let tb = gb * 1024
    if bytes >= tb { return String(format: "%.2f TB", Double(bytes) / Double(tb)) }
    if bytes >= gb { return String(format: "%.2f GB", Double(bytes) / Double(gb)) }
    if bytes >= mb { return String(format: "%.2f MB", Double(bytes) / Double(mb)) }
    if bytes >= kb { return String(format: "%.2f KB", Double(bytes) / Double(kb)) }
    return "\(bytes) B"
}
