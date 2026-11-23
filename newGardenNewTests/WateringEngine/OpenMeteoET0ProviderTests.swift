import Testing
import Foundation
@testable import newGardenNew

/// Decoding only, no network — a live call belongs in a manual smoke check, not a suite that
/// runs on every build. Confirms the response contract this app actually depends on
/// (`daily.et0_fao_evapotranspiration`) hasn't silently changed shape.
struct OpenMeteoET0ProviderTests {
    @Test("Decodes Open-Meteo's real response shape for et0_fao_evapotranspiration")
    func decodesDailyEt0() throws {
        let json = """
        {
            "latitude": -33.45,
            "longitude": -70.65,
            "daily": {
                "time": ["2026-09-19"],
                "et0_fao_evapotranspiration": [3.87]
            }
        }
        """
        let decoded = try JSONDecoder().decode(OpenMeteoET0Response.self, from: Data(json.utf8))
        #expect(decoded.daily.et0FaoEvapotranspiration == [3.87])
    }

    @Test("Missing daily data throws noData instead of returning a bogus zero")
    func missingDataThrows() async {
        struct EmptyDataSession {
            static let json = """
            { "latitude": 0, "longitude": 0, "daily": { "time": [], "et0_fao_evapotranspiration": [] } }
            """
        }
        let decoded = try? JSONDecoder().decode(OpenMeteoET0Response.self, from: Data(EmptyDataSession.json.utf8))
        #expect(decoded?.daily.et0FaoEvapotranspiration.first == nil)
    }
}
