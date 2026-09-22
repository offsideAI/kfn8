import Testing
@testable import Kfn8M0ProbeCore

@Suite struct ProbeCatalogTests {
    @Test func exactlyThreeBlockingProbes() {
        #expect(ProbeKind.allCases.filter(\.isBlocking) == [.lighting, .occlusion, .manipulation])
    }

    @Test func everyProbeCitesInstalledSDKSymbols() {
        for probe in ProbeKind.allCases {
            #expect(!probe.sdkSymbols.isEmpty, "\(probe) must cite SDK symbols, not marketing names")
        }
    }

    @Test func splatCitationRecordsMissingFileLoader() {
        #expect(ProbeKind.splat.sdkSymbols.contains { $0.contains("no file loader") })
    }
}
