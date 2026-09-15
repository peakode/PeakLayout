import Foundation

/// Bir klasördeki ekleme/silme/yeniden adlandırmaları izler, olayları debounce eder.
final class DirectoryWatcher {
    private let url: URL
    private let debounce: TimeInterval
    private let onChange: @MainActor () -> Void
    private var source: DispatchSourceFileSystemObject?
    private var pending: DispatchWorkItem?

    init(url: URL, debounce: TimeInterval = 1.5, onChange: @escaping @MainActor () -> Void) {
        self.url = url
        self.debounce = debounce
        self.onChange = onChange
    }

    func start() {
        guard source == nil else { return }
        let fd = open(url.path, O_EVTONLY)
        guard fd >= 0 else { return }
        let source = DispatchSource.makeFileSystemObjectSource(
            fileDescriptor: fd,
            eventMask: [.write, .rename, .delete, .link],
            queue: .main
        )
        source.setEventHandler { [weak self] in self?.schedule() }
        source.setCancelHandler { close(fd) }
        source.resume()
        self.source = source
    }

    func stop() {
        pending?.cancel()
        source?.cancel()
        source = nil
    }

    private func schedule() {
        pending?.cancel()
        let work = DispatchWorkItem { [onChange] in
            MainActor.assumeIsolated { onChange() }
        }
        pending = work
        DispatchQueue.main.asyncAfter(deadline: .now() + debounce, execute: work)
    }

    deinit { stop() }
}
