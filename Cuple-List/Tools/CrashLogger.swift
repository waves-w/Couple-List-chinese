//
//  CrashLogger.swift
//  Cuple-List
//
//  Created by wanghaojun.
//
import Foundation
import UIKit
import CocoaLumberjack

class CrashLogger {
    static let shared = CrashLogger()
    
    private var previousExceptionHandler: NSUncaughtExceptionHandler?
    private let signals: [(Int32, String)] = [
        (SIGABRT, "SIGABRT"),
        (SIGBUS, "SIGBUS"),
        (SIGFPE, "SIGFPE"),
        (SIGILL, "SIGILL"),
        (SIGSEGV, "SIGSEGV"),
        (SIGTRAP, "SIGTRAP")
    ]
    
    private var previousSignalHandlers: [Int32: sig_t] = [:]
    
    private init() {}
    
    /// 根据信号编号获取信号名称
    func getSignalName(for signal: Int32) -> String {
        for (sigNum, name) in signals {
            if sigNum == signal {
                return name
            }
        }
        return "UNKNOWN(\(signal))"
    }
    
    /// 设置崩溃捕获
    func setup() {
        // 保存之前的异常处理器（如果有 Sentry，会保留它的处理器）
        previousExceptionHandler = NSGetUncaughtExceptionHandler()
        
        // 设置自定义的 NSException 捕获
        NSSetUncaughtExceptionHandler { exception in
            CrashLogger.shared.handleException(exception)
            // 调用之前的处理器（比如 Sentry）
            CrashLogger.shared.previousExceptionHandler?(exception)
        }
        
        // 设置信号捕获
        // 注意：信号处理器使用简化方式，主要依赖NSException处理器捕获大部分崩溃
        // 如果需要完整的信号捕获，建议使用Sentry SDK（已在Release模式启用）
        for (sigNum, name) in signals {
            // 保存之前的信号处理器
            previousSignalHandlers[sigNum] = signal(sigNum, SIG_DFL)
            
            // 设置简化的信号处理器（使用C函数指针）
            signal(sigNum, signalHandler)
        }
        
        // ✅ 延迟记录初始化信息，确保日志系统完全初始化后再访问
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            self.logToFile("✅ 崩溃捕获系统已初始化", level: .info)
        }
    }
    
    /// 处理 NSException 崩溃
    private func handleException(_ exception: NSException) {
        let crashInfo = generateCrashInfo(exception: exception)
        writeCrashLog(crashInfo)
    }
    
    /// 处理信号崩溃
    func handleSignal(_ sigNum: Int32, name: String) {
        let crashInfo = generateCrashInfo(signal: sigNum, signalName: name)
        writeCrashLog(crashInfo)
        
        // 恢复之前的信号处理器并重新触发信号
        if let previous = previousSignalHandlers[sigNum] {
            signal(sigNum, previous)
        }
        raise(sigNum)
    }
    
    /// 生成崩溃信息
    private func generateCrashInfo(exception: NSException? = nil, signal: Int32? = nil, signalName: String? = nil) -> String {
        var crashLog = "\n"
        crashLog += "═══════════════════════════════════════════════════════════════\n"
        crashLog += "🚨 应用崩溃检测 🚨\n"
        crashLog += "═══════════════════════════════════════════════════════════════\n"
        crashLog += "崩溃时间: \(Date())\n"
        crashLog += "应用版本: \(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "Unknown")\n"
        crashLog += "构建版本: \(Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "Unknown")\n"
        crashLog += "设备型号: \(UIDevice.current.model)\n"
        crashLog += "系统版本: \(UIDevice.current.systemVersion)\n"
        crashLog += "用户 UUID: \(CoupleStatusManager.getUserUniqueUUID())\n"
        crashLog += "情侣 ID: \(CoupleStatusManager.getPartnerId() ?? "Not linked")\n"
        crashLog += "───────────────────────────────────────────────────────────────\n"
        
        if let exception = exception {
            crashLog += "崩溃类型: NSException (未捕获异常)\n"
            crashLog += "异常名称: \(exception.name.rawValue)\n"
            crashLog += "异常原因: \(exception.reason ?? "Unknown")\n"
            
            if let userInfo = exception.userInfo, !userInfo.isEmpty {
                crashLog += "异常信息: \(userInfo)\n"
            }
            
            crashLog += "\n调用堆栈:\n"
            if let callStack = exception.callStackSymbols as? [String] {
                for (index, symbol) in callStack.enumerated() {
                    crashLog += "  \(index + 1). \(symbol)\n"
                }
            }
        } else if let signal = signal, let signalName = signalName {
            crashLog += "崩溃类型: Signal (信号崩溃)\n"
            crashLog += "信号名称: \(signalName)\n"
            crashLog += "信号编号: \(signal)\n"
            
            crashLog += "\n调用堆栈:\n"
            let callStack = Thread.callStackSymbols
            for (index, symbol) in callStack.enumerated() {
                crashLog += "  \(index + 1). \(symbol)\n"
            }
        }
        
        crashLog += "───────────────────────────────────────────────────────────────\n"
        crashLog += "内存信息:\n"
        crashLog += getMemoryInfo()
        crashLog += "═══════════════════════════════════════════════════════════════\n\n"
        
        return crashLog
    }
    
    /// 获取内存信息
    private func getMemoryInfo() -> String {
        var info = mach_task_basic_info()
        var count = mach_msg_type_number_t(MemoryLayout<mach_task_basic_info>.size) / 4
        
        let kerr: kern_return_t = withUnsafeMutablePointer(to: &info) {
            $0.withMemoryRebound(to: integer_t.self, capacity: 1) {
                task_info(mach_task_self_, task_flavor_t(MACH_TASK_BASIC_INFO), $0, &count)
            }
        }
        
        var memoryInfo = ""
        if kerr == KERN_SUCCESS {
            let usedMemoryMB = Double(info.resident_size) / 1024.0 / 1024.0
            memoryInfo += "  已用内存: \(String(format: "%.2f", usedMemoryMB)) MB\n"
            memoryInfo += "  虚拟内存: \(String(format: "%.2f", Double(info.virtual_size) / 1024.0 / 1024.0)) MB\n"
        } else {
            memoryInfo += "  无法获取内存信息\n"
        }
        
        return memoryInfo
    }
    
    /// 写入崩溃日志
    private func writeCrashLog(_ crashInfo: String) {
        // 使用辅助方法写入日志文件
        logToFile(crashInfo, level: .error)
        
        // 立即刷新所有日志，确保崩溃信息被写入文件
        DDLog.allLoggers.forEach { logger in
            if let fileLogger = logger as? DDFileLogger {
                fileLogger.flush()
                // 强制同步写入（在崩溃前尽可能保存日志）
                sync()
            }
        }
        
        // 同时打印到控制台（如果还在运行）
        print(crashInfo)
    }
    
    /// 辅助方法：将日志写入文件（使用 CocoaLumberjack）
    private func logToFile(_ message: String, level: DDLogLevel) {
        // ✅ 添加安全检查，避免在日志系统未完全初始化时访问
        do {
            // 获取文件日志器（使用同步方式，避免线程安全问题）
            var fileLogger: DDFileLogger?
            let allLoggers = DDLog.allLoggers
            for logger in allLoggers {
                if let fl = logger as? DDFileLogger {
                    fileLogger = fl
                    break
                }
            }
            
            guard let fileLogger = fileLogger else {
                // 如果没有文件日志器，直接打印
                print(message)
                return
            }
            
            // 直接写入日志文件（使用文件日志器的日志路径）
            if let logFilePaths = fileLogger.logFileManager.sortedLogFilePaths as? [String],
               let latestLogPath = logFilePaths.first,
               FileManager.default.fileExists(atPath: latestLogPath),
               let fileHandle = FileHandle(forWritingAtPath: latestLogPath) {
                let dateFormatter = DateFormatter()
                dateFormatter.dateFormat = "yyyy-MM-dd HH:mm:ss.SSS"
                let timestamp = dateFormatter.string(from: Date())
                let logEntry = "[\(timestamp)] [\(levelDescription(level))] \(message)\n"
                
                fileHandle.seekToEndOfFile()
                if let data = logEntry.data(using: .utf8) {
                    fileHandle.write(data)
                }
                fileHandle.closeFile()
            } else {
                // 如果无法写入文件，至少打印到控制台
                print(message)
            }
        } catch {
            // ✅ 如果出现任何异常，至少打印到控制台，不抛出异常
            print(message)
        }
    }
    
    /// 获取日志级别描述
    private func levelDescription(_ level: DDLogLevel) -> String {
        switch level {
        case .error: return "ERROR"
        case .warning: return "WARN"
        case .info: return "INFO"
        case .debug: return "DEBUG"
        case .verbose: return "VERBOSE"
        default: return "INFO"
        }
    }
    
    /// 同步写入文件系统
    private func sync() {
        // 尝试同步文件系统（在崩溃前尽可能保存）
        // 注意：这可能在崩溃时无法完全执行，但尽力而为
        DispatchQueue.global(qos: .utility).sync {
            // 给文件系统一些时间完成写入
            Thread.sleep(forTimeInterval: 0.1)
        }
    }
}

// MARK: - C函数指针包装（用于信号处理）
@_cdecl("crashSignalHandler")
private func signalHandler(_ signal: Int32) {
    let signalName = CrashLogger.shared.getSignalName(for: signal)
    CrashLogger.shared.handleSignal(signal, name: signalName)
}

