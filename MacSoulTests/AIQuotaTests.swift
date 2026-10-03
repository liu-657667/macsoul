import XCTest
@testable import MacSoul

private let quotaTestNow = Date(timeIntervalSince1970: 1_800_000_000)
private func wireWindow(_ used: Any = 42, minutes: Any = 300, reset: Any = 1_800_010_000) -> [String: Any] {
    ["usedPercent": used, "windowDurationMins": minutes, "resetsAt": reset]
}
private func wirePayload(primary: [String: Any]? = wireWindow(), secondary: [String: Any]? = wireWindow(31, minutes: 10080)) -> [String: Any] {
    var bucket: [String: Any] = ["limitId": "codex"]
    if let primary { bucket["primary"] = primary }
    if let secondary { bucket["secondary"] = secondary }
    return ["rateLimits": bucket]
}
private func liveItem(used: Double = 95, reset: Date? = quotaTestNow.addingTimeInterval(1000),
                      sampledAt: Date? = quotaTestNow, provider: QuotaProvider = .codex) -> QuotaItem {
    QuotaItem(provider: provider, fiveHour: .available(QuotaWindow(usedPercent: used, durationMinutes: 300, resetsAt: reset)!),
              weekly: .unreported, sampledAt: sampledAt, source: "Test fixture", freshness: .fresh, mode: .live)
}
final class AIQuotaParserTests: XCTestCase {
    func testBothWindowsAreUsedPercentAndPreserveEpochReset() throws {
        let item = try CodexQuotaParser.parse(wirePayload(), now: quotaTestNow)
        XCTAssertEqual(item.displayWindows(now: quotaTestNow).map { $0.state.value?.usedPercent }, [42, 31])
        XCTAssertEqual(item.displayWindows(now: quotaTestNow)[0].state.value?.resetsAt, Date(timeIntervalSince1970: 1_800_010_000))
        XCTAssertEqual(item.mode, .live)
    }
    func testWeekOnlyOmissionRemainsUnreported() throws {
        let item = try CodexQuotaParser.parse(wirePayload(primary: nil), now: quotaTestNow)
        XCTAssertEqual(item.fiveHour, .unreported)
        XCTAssertTrue(item.notApplicableLabels().isEmpty)
    }
    func testFiveHourOnlyDoesNotInventWeek() throws {
        let item = try CodexQuotaParser.parse(wirePayload(secondary: nil), now: quotaTestNow)
        XCTAssertEqual(item.weekly, .unreported)
    }
    func testContainerOrderDoesNotDetermineDurationMeaning() throws {
        let item = try CodexQuotaParser.parse(wirePayload(primary: wireWindow(8, minutes: 10080), secondary: wireWindow(60)), now: quotaTestNow)
        XCTAssertEqual(item.displayWindows(now: quotaTestNow).map { $0.state.value?.usedPercent }, [60, 8])
    }
    func testValidZeroAndHundredRemainAvailable() throws {
        let item = try CodexQuotaParser.parse(wirePayload(primary: wireWindow(0), secondary: wireWindow(100, minutes: 10080)), now: quotaTestNow)
        XCTAssertEqual(item.displayWindows(now: quotaTestNow).map { $0.state.value?.usedPercent }, [0, 100])
    }
    func testDurationRoundingTolerancePreservesSourceMinutes() throws {
        for offset in [-1, 1] {
            let item = try CodexQuotaParser.parse(wirePayload(primary: wireWindow(minutes: 300 + offset),
                secondary: wireWindow(31, minutes: 10080 + offset)), now: quotaTestNow)
            XCTAssertEqual(item.displayWindows(now: quotaTestNow).map { $0.state.value?.durationMinutes },
                           [300 + offset, 10080 + offset])
        }
        let outside = try CodexQuotaParser.parse(wirePayload(primary: wireWindow(minutes: 298),
            secondary: wireWindow(31, minutes: 10082)), now: quotaTestNow)
        XCTAssertEqual(outside.fiveHour, .unreported)
        XCTAssertEqual(outside.weekly, .unreported)
    }
    func testInvalidPercentNeverClamps() throws {
        for raw: Any in [-1, 101, Double.nan, Double.infinity, "42", true] {
            let item = try CodexQuotaParser.parse(wirePayload(primary: wireWindow(raw)), now: quotaTestNow)
            XCTAssertEqual(item.fiveHour, .requestFailed)
            guard case .available = item.weekly else { return XCTFail("Valid Week must survive") }
        }
    }
    func testMalformedDurationRejected() {
        for raw: Any in [0, -300, 300.5, "300", true, NSNull(), Double.infinity] {
            XCTAssertThrowsError(try CodexQuotaParser.parse(wirePayload(primary: wireWindow(minutes: raw)), now: quotaTestNow))
        }
    }
    func testMalformedResetRejected() throws {
        for raw: Any in [-1, 0, "tomorrow", true, Double.infinity, 253_402_300_800.0] {
            let item = try CodexQuotaParser.parse(wirePayload(primary: wireWindow(reset: raw)), now: quotaTestNow)
            XCTAssertEqual(item.fiveHour, .requestFailed)
            guard case .available = item.weekly else { return XCTFail("Valid Week must survive") }
        }
    }
    func testMissingResetStaysUnknownNotNowPlusDuration() throws {
        let item = try CodexQuotaParser.parse(wirePayload(primary: wireWindow(reset: NSNull())), now: quotaTestNow)
        XCTAssertNil(item.displayWindows(now: quotaTestNow)[0].state.value?.resetsAt)
    }
    func testDuplicateDurationFailsOnlyItsWindow() throws {
        let five = try CodexQuotaParser.parse(wirePayload(secondary: wireWindow(31)), now: quotaTestNow)
        XCTAssertEqual(five.fiveHour, .requestFailed); XCTAssertEqual(five.weekly, .unreported)
        let week = try CodexQuotaParser.parse(wirePayload(primary: wireWindow(minutes: 10080)), now: quotaTestNow)
        XCTAssertEqual(week.weekly, .requestFailed); XCTAssertEqual(week.fiveHour, .unreported)
    }
    func testUnknownWindowIgnoredWithoutClaimingNotApplicable() throws {
        let item = try CodexQuotaParser.parse(wirePayload(primary: wireWindow(minutes: 15), secondary: nil), now: quotaTestNow)
        XCTAssertEqual(item.fiveHour, .unreported); XCTAssertEqual(item.weekly, .unreported)
    }
    func testMultiBucketSelectsCodexAndIgnoresOtherBuckets() throws {
        let payload: [String: Any] = ["rateLimits": ["primary": wireWindow(99)],
            "rateLimitsByLimitId": ["codex": ["primary": wireWindow(8)], "codex_other": ["primary": wireWindow(99)]]]
        let item = try CodexQuotaParser.parse(payload, now: quotaTestNow)
        XCTAssertEqual(item.displayWindows(now: quotaTestNow)[0].state.value?.usedPercent, 8)
    }
    func testUnidentifiedBucketsFailWithoutLegacyFallback() {
        XCTAssertThrowsError(try CodexQuotaParser.parse(["rateLimitsByLimitId": [
            "other": ["primary": wireWindow(99)], "future": ["primary": wireWindow(0)]
        ]], now: quotaTestNow)) { XCTAssertEqual($0 as? QuotaParseError, .ambiguousBucket) }
    }
    func testLegacyWrongBucketIsRejected() {
        XCTAssertThrowsError(try CodexQuotaParser.parse(["rateLimits": ["limitId": "other", "primary": wireWindow()]], now: quotaTestNow))
    }
    func testMalformedEnvelopeDoesNotBecomeMissingOrZero() {
        for payload: [String: Any] in [[:], ["rateLimits": "bad"], ["rateLimitsByLimitId": []]] {
            XCTAssertThrowsError(try CodexQuotaParser.parse(payload, now: quotaTestNow))
        }
    }
    func testNullBucketSuccessMeansUnreported() throws {
        let item = try CodexQuotaParser.parse(["rateLimits": NSNull()], now: quotaTestNow)
        XCTAssertEqual(item.fiveHour, .unreported); XCTAssertEqual(item.weekly, .unreported)
    }
    func testElapsedSampleAndResetRetainUsageAsStale() {
        let item = liveItem()
        XCTAssertEqual(item.displayWindows(now: quotaTestNow.addingTimeInterval(301))[0].state.value?.usedPercent, 95)
        XCTAssertTrue(item.alertEligibleWindows(now: quotaTestNow.addingTimeInterval(301)).isEmpty)
        guard case .stale = item.displayWindows(now: quotaTestNow.addingTimeInterval(1001))[0].state else { return XCTFail("Expected stale") }
    }
    func testUnrelatedSensitiveFieldsAreNotRepresentedInResult() throws {
        var payload = wirePayload(); payload["email"] = "fake@example.invalid"; payload["conversation"] = ["fake"]
        let result = try CodexQuotaParser.parse(payload, now: quotaTestNow)
        XCTAssertEqual(result, try CodexQuotaParser.parse(wirePayload(), now: quotaTestNow))
    }
    func testObservedPrimaryWeekOnlyShape() throws {
        let item = try CodexQuotaParser.parse(wirePayload(primary: wireWindow(37, minutes: 10080), secondary: nil), now: quotaTestNow)
        XCTAssertEqual(item.fiveHour, .unreported)
        XCTAssertEqual(item.presentationWindows(now: quotaTestNow, presentation: .summary).map(\.kind), [.weekly])
        XCTAssertEqual(item.displayWindows(now: quotaTestNow).last?.state.value?.usedPercent, 37)
    }
    func testBothContainerOrdersProduceExactlySameItem() throws {
        let five = wireWindow(0), week = wireWindow(52, minutes: 10080)
        XCTAssertEqual(try CodexQuotaParser.parse(wirePayload(primary: five, secondary: week), now: quotaTestNow),
                       try CodexQuotaParser.parse(wirePayload(primary: week, secondary: five), now: quotaTestNow))
    }
    func testUnknownWindowsDoNotInvalidateRecognizedWindows() throws {
        for minutes in [15, 60, 720] {
            let unknown = wireWindow("not-telemetry", minutes: minutes, reset: "not-a-reset")
            let five = try CodexQuotaParser.parse(wirePayload(primary: wireWindow(), secondary: unknown), now: quotaTestNow)
            XCTAssertEqual(five.weekly, .unreported)
            guard case .available = five.fiveHour else { return XCTFail("Preserve 5h") }
            let week = try CodexQuotaParser.parse(wirePayload(primary: unknown, secondary: wireWindow(31, minutes: 10080)), now: quotaTestNow)
            XCTAssertEqual(week.fiveHour, .unreported)
            guard case .available = week.weekly else { return XCTFail("Preserve Week") }
        }
    }
    func testUnidentifiedMapUsesDocumentedLegacyView() throws {
        var payload = wirePayload()
        payload["rateLimitsByLimitId"] = ["other": ["primary": wireWindow(99)]]
        XCTAssertEqual(try CodexQuotaParser.parse(payload, now: quotaTestNow),
                       try CodexQuotaParser.parse(wirePayload(), now: quotaTestNow))
    }
    func testExplicitLimitIdentitySelectsUniqueBucketRegardlessOfKeyOrder() throws {
        let item = try CodexQuotaParser.parse(["rateLimitsByLimitId": [
            "z": ["limitId": "codex", "primary": wireWindow(7)], "a": ["primary": wireWindow(99)]
        ]], now: quotaTestNow)
        XCTAssertEqual(item.displayWindows(now: quotaTestNow).first?.state.value?.usedPercent, 7)
    }
    func testAmbiguousExplicitCodexIdentitiesFail() {
        XCTAssertThrowsError(try CodexQuotaParser.parse(["rateLimitsByLimitId": [
            "a": ["limitId": "codex"], "b": ["limitId": "codex"]
        ]], now: quotaTestNow))
    }
    private func planPayload(_ plan: Any, withFive: Bool = false) -> [String: Any] {
        var bucket: [String: Any] = ["planType": plan, "primary": wireWindow(35, minutes: 10080)]
        if withFive { bucket["secondary"] = wireWindow(19) }
        return ["rateLimitsByLimitId": ["codex": bucket]]
    }
    func testVerifiedNoFiveHourProAndWeekOnlyIsNotApplicable() throws {
        for plan in ["pro", "prolite", "promax"] {
            let item = try CodexQuotaParser.parse(planPayload(plan), now: quotaTestNow)
            XCTAssertEqual(item.fiveHour, .notApplicable)
            guard case .available = item.weekly else { return XCTFail("Week remains numeric") }
            XCTAssertEqual(item.presentationWindows(now: quotaTestNow, presentation: .summary).map(\.kind), [.weekly])
        }
    }
    func testUnknownPlanAndWeekOnlyRemainsUnreported() throws {
        XCTAssertEqual(try CodexQuotaParser.parse(planPayload("unknown"), now: quotaTestNow).fiveHour, .unreported)
    }
    func testPlusWithBothReportedWindowsRemainsAvailable() throws {
        let item = try CodexQuotaParser.parse(planPayload("plus", withFive: true), now: quotaTestNow)
        XCTAssertEqual(item.displayWindows(now: quotaTestNow).compactMap { $0.state.value?.usedPercent }, [19, 35])
    }
    func testProActualFiveHourWindowWinsOverPolicy() throws {
        let item = try CodexQuotaParser.parse(planPayload("pro", withFive: true), now: quotaTestNow)
        guard case .available(let five) = item.fiveHour else { return XCTFail("Reported window wins") }
        XCTAssertEqual(five.usedPercent, 19)
    }
    func testFutureMalformedAndDisplayPlanNamesAreConservative() throws {
        for plan: Any in ["future_pro", "Pro", "Pro 200", "self_serve_business_prolite", "edu_pro", true, NSNull(), [:]] {
            XCTAssertEqual(try CodexQuotaParser.parse(planPayload(plan), now: quotaTestNow).fiveHour, .unreported)
        }
    }
    func testOnlySelectedBucketPlanCanClassifyMissingWindow() throws {
        var payload = wirePayload(primary: wireWindow(minutes: 10080), secondary: nil)
        payload["planType"] = "pro"
        payload["rateLimitsByLimitId"] = ["other": ["planType": "pro"]]
        XCTAssertEqual(try CodexQuotaParser.parse(payload, now: quotaTestNow).fiveHour, .unreported)
    }
    func testReportedInvalidFiveHourCannotBeHiddenByProPolicy() throws {
        var payload = planPayload("pro", withFive: true)
        var buckets = payload["rateLimitsByLimitId"] as! [String: Any]
        var bucket = buckets["codex"] as! [String: Any]
        bucket["secondary"] = wireWindow(101)
        buckets["codex"] = bucket; payload["rateLimitsByLimitId"] = buckets
        XCTAssertEqual(try CodexQuotaParser.parse(payload, now: quotaTestNow).fiveHour, .requestFailed)
    }
    func testSummaryOmitsOnlyLiveUnreportedAndDetailPreservesIt() throws {
        let live = try CodexQuotaParser.parse(planPayload("unknown"), now: quotaTestNow)
        XCTAssertEqual(live.presentationWindows(now: quotaTestNow, presentation: .summary).count, 1)
        XCTAssertEqual(live.presentationWindows(now: quotaTestNow, presentation: .detail).count, 2)
        let preview = MockProvider(fixture: .codexUnreported).snapshot(now: quotaTestNow).quotas[0]
        XCTAssertEqual(preview.presentationWindows(now: quotaTestNow, presentation: .summary), preview.displayWindows(now: quotaTestNow))
    }
    @MainActor func testClaudeBothAndWeeklyOnlyUseExplicitKeys() throws {
        let limits: [String: Any] = ["five_hour": ["used_percentage": 95, "resets_at": 1_800_010_000],
            "seven_day": ["used_percentage": 0, "resets_at": 1_800_020_000]]
        let both = ClaudeQuotaProvider.map(capability: .available, sanitizedLimits: limits, sampledAt: quotaTestNow)
        XCTAssertEqual(both.displayWindows(now: quotaTestNow).map { $0.state.value?.usedPercent }, [95, 0])
        let week = try ClaudeQuotaParser.parse(["seven_day": limits["seven_day"]!], sampledAt: quotaTestNow)
        XCTAssertEqual(week.fiveHour, .unreported)
        let five = try ClaudeQuotaParser.parse(["five_hour": limits["five_hour"]!], sampledAt: quotaTestNow)
        XCTAssertEqual(five.weekly, .unreported)
    }
    @MainActor func testClaudeNoAuthNoSubscriptionUnsupportedNeverZero() {
        for state: ClaudeQuotaCapability in [.notInstalled, .detectedUnauthenticated, .detectedNoSubscriptionQuota, .unsupportedVersion, .noVerifiedSource] {
            let item = ClaudeQuotaProvider.map(capability: state)
            XCTAssertTrue(item.entirelyUnavailable); XCTAssertTrue(item.alertEligibleWindows(now: quotaTestNow).isEmpty)
        }
    }
    @MainActor func testClaudeReadFailureAndSuccessfulMissingDiffer() {
        XCTAssertEqual(ClaudeQuotaProvider.map(capability: .requestFailed).weekly, .requestFailed)
        XCTAssertEqual(ClaudeQuotaProvider.map(capability: .available).weekly, .unreported)
    }
    @MainActor func testClaudeMalformedPercentOrResetBecomesRequestFailure() {
        for value: [String: Any] in [["used_percentage": -1], ["used_percentage": 101],
             ["used_percentage": 50, "resets_at": "bad"]] {
            XCTAssertEqual(ClaudeQuotaProvider.map(capability: .available, sanitizedLimits: ["five_hour": value]).fiveHour, .requestFailed)
        }
    }
    func testClaudeStaleFixtureRetainsLastUsage() throws {
        let item = try ClaudeQuotaParser.parse(["five_hour": ["used_percentage": 95, "resets_at": 1_800_010_000]], sampledAt: quotaTestNow.addingTimeInterval(-301))
        guard case .stale(let window) = item.displayWindows(now: quotaTestNow)[0].state else { return XCTFail("Expected stale") }
        XCTAssertEqual(window.usedPercent, 95)
    }
    func testClaudeSpendLimitIsNotSubscriptionQuota() throws {
        let item = try ClaudeQuotaParser.parse(["spend_limit": ["used_percentage": 15]], sampledAt: quotaTestNow)
        XCTAssertEqual(item.fiveHour, .unreported); XCTAssertEqual(item.weekly, .unreported)
    }
    func testVersionMetadataRejectsDiagnostics() {
        XCTAssertEqual(QuotaExecutableDiscovery.version("2.1.90 (Claude Code)"), "2.1.90")
        XCTAssertNil(QuotaExecutableDiscovery.version("login required"))
    }
    func testRPCAllowlistRejectsTasksAndAccountMutations() {
        for method in ["thread/start", "turn/start", "account/read", "account/login/start", "account/logout", "account/usage/read"] {
            XCTAssertThrowsError(try CodexReadOnlyRPC.message(method: method, id: 1))
        }
    }
    func testRPCInitializeAndReadHaveNoPromptOrTokens() throws {
        for method in ["initialize", "initialized", "account/rateLimits/read"] {
            let data = try CodexReadOnlyRPC.message(method: method, id: method == "initialized" ? nil : 1)
            let value = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
            XCTAssertEqual(value["method"] as? String, method)
            XCTAssertNil(value["prompt"]); XCTAssertNil(value["token"])
        }
    }
    func testFragmentedJSONLinesAndOversizedLineBound() throws {
        var buffer = CodexLineBuffer()
        XCTAssertTrue(try buffer.append(Data("{\"id\":1".utf8)).isEmpty)
        XCTAssertEqual(try buffer.append(Data("}\n{}\n".utf8)), [Data("{\"id\":1}".utf8), Data("{}".utf8)])
        XCTAssertFalse(buffer.hasPartialLine)
        XCTAssertThrowsError(try buffer.append(Data(repeating: 65, count: CodexLineBuffer.limit + 1)))
    }
    func testCappedBackoffAndSuccessReset() {
        var backoff = QuotaBackoff()
        XCTAssertEqual((0..<8).map { _ in backoff.next() }, [1, 2, 5, 10, 30, 60, 60, 60])
        backoff.reset(); XCTAssertEqual(backoff.next(), 1)
    }
    func testProviderStatusLocalizesWithoutRawValues() {
        XCTAssertEqual(MacSoulLanguage.chinese.quotaStatus(QuotaProviderDetail(provider: .codex, connection: .malformed)), "配额响应格式无效")
        XCTAssertEqual(MacSoulLanguage.chinese.quotaStatus(QuotaProviderDetail(provider: .claude, connection: .unavailable, claudeCapability: .notInstalled)), "未检测到")
    }
}

final class QuotaAlertEngineTests: XCTestCase {
    func testNinetyFourDoesNotAlert() { XCTAssertTrue(QuotaAlertEngine().evaluate([liveItem(used: 94)], now: quotaTestNow).isEmpty) }
    func testNinetyFiveAlertsAndDeduplicatesReset() {
        let engine = QuotaAlertEngine()
        XCTAssertEqual(engine.evaluate([liveItem()], now: quotaTestNow).count, 1)
        XCTAssertTrue(engine.evaluate([liveItem(used: 99)], now: quotaTestNow).isEmpty)
    }
    func testValidHundredAlerts() { XCTAssertEqual(QuotaAlertEngine().evaluate([liveItem(used: 100)], now: quotaTestNow).count, 1) }
    func testNextResetAllowsNewAlert() {
        let engine = QuotaAlertEngine()
        XCTAssertEqual(engine.evaluate([liveItem()], now: quotaTestNow).count, 1)
        XCTAssertEqual(engine.evaluate([liveItem(reset: quotaTestNow.addingTimeInterval(2000))], now: quotaTestNow).count, 1)
    }
    func testStaleSampleOrExpiredResetCannotAlert() {
        let engine = QuotaAlertEngine()
        XCTAssertTrue(engine.evaluate([liveItem(sampledAt: quotaTestNow.addingTimeInterval(-301)), liveItem(reset: quotaTestNow)], now: quotaTestNow).isEmpty)
    }
    func testNonNumericStatesCannotAlertOrDriveSoul() {
        for state: QuotaWindowState in [.unreported, .notApplicable, .requestFailed, .providerUnavailable] {
            let item = QuotaItem(provider: .claude, fiveHour: state, weekly: state, sampledAt: quotaTestNow, source: "Fixture", freshness: .fresh, mode: .live)
            XCTAssertTrue(QuotaAlertEngine().evaluate([item], now: quotaTestNow).isEmpty)
            XCTAssertTrue(item.alertEligibleWindows(now: quotaTestNow).isEmpty)
        }
    }
    func testMissingResetCannotInventDedupeWindow() {
        XCTAssertTrue(QuotaAlertEngine().evaluate([liveItem(reset: nil)], now: quotaTestNow).isEmpty)
    }
    func testMockDoesNotEmitRuntimeAlert() {
        XCTAssertTrue(QuotaAlertEngine().evaluate(MockProvider(fixture: .quota95).snapshot(now: quotaTestNow).quotas, now: quotaTestNow).isEmpty)
    }
    func testProviderAndWindowIdentitiesAreIndependent() {
        let engine = QuotaAlertEngine()
        let codex = liveItem(), claude = liveItem(provider: .claude)
        XCTAssertEqual(engine.evaluate([codex, claude], now: quotaTestNow).count, 2)
        let week = QuotaItem(provider: .codex, fiveHour: .unreported, weekly: .available(QuotaWindow(usedPercent: 95, durationMinutes: 10080, resetsAt: quotaTestNow.addingTimeInterval(1000))!), sampledAt: quotaTestNow, source: "Fixture", freshness: .fresh, mode: .live)
        XCTAssertEqual(engine.evaluate([week], now: quotaTestNow).first?.kind, .weekly)
    }
}

final class QuotaRemainingPresentationTests: XCTestCase {
    private func window(_ used: Double) -> QuotaWindow {
        QuotaWindow(usedPercent: used, durationMinutes: 10080, resetsAt: nil)!
    }
    func testRemainingExamplesRetainCanonicalUsedValue() {
        for (used, remaining): (Double, Double) in [(0,100), (4,96), (95,5), (100,0)] {
            let value = window(used)
            XCTAssertEqual(value.usedPercent, used)
            XCTAssertEqual(value.remainingPercent, remaining)
        }
    }
    func testRemainingProgressMatchesNumericSemantics() {
        XCTAssertEqual(window(0).remainingProgress, 1)
        XCTAssertEqual(window(4).remainingProgress, 0.96, accuracy: 0.000001)
        XCTAssertEqual(window(95).remainingProgress, 0.05, accuracy: 0.000001)
        XCTAssertEqual(window(100).remainingProgress, 0)
    }
    func testExactChineseAndEnglishRemainingCopy() {
        XCTAssertEqual(MacSoulLanguage.chinese.remaining(96), "剩余 96%")
        XCTAssertEqual(MacSoulLanguage.english.remaining(96), "96% remaining")
        let row = QuotaDisplayWindow(kind: .weekly, state: .fresh(window(4)))
        XCTAssertEqual(QuotaWindowView.statusLabel(for: row, now: quotaTestNow, language: .chinese, presentation: .detail), "剩余 96% · 新鲜")
        XCTAssertEqual(QuotaWindowView.statusLabel(for: row, now: quotaTestNow, language: .english, presentation: .detail), "96% remaining · Fresh")
    }
    func testAllPresentationsUseRemainingAndAlertSeverityStaysUsed() {
        let row = QuotaDisplayWindow(kind: .weekly, state: .fresh(window(95)))
        for presentation: QuotaPresentation in [.summary, .detail] {
            let copy = QuotaWindowView.statusLabel(for: row, now: quotaTestNow, language: .english, presentation: presentation)
            XCTAssertTrue(copy.contains("5% remaining")); XCTAssertTrue(copy.contains("Near limit"))
        }
        XCTAssertEqual(QuotaAlertEngine().evaluate([liveItem(used: 95)], now: quotaTestNow).count, 1)
        XCTAssertTrue(QuotaAlertEngine().evaluate([liveItem(used: 94)], now: quotaTestNow).isEmpty)
    }
    func testStaleNumericDoesNotResetRemainingToHundred() {
        let row = QuotaDisplayWindow(kind: .weekly, state: .stale(window(4)))
        XCTAssertEqual(QuotaWindowView.statusLabel(for: row, now: quotaTestNow, language: .chinese, presentation: .summary), "剩余 96% · 已过期")
        XCTAssertEqual(QuotaWindowView.statusLabel(for: row, now: quotaTestNow, language: .english, presentation: .summary), "96% remaining · Stale")
    }
    func testNonNumericStatesNeverInventRemaining() {
        for state: QuotaDisplayState in [.unreported, .providerUnavailable, .requestFailed] {
            let row = QuotaDisplayWindow(kind: .weekly, state: state)
            XCTAssertNil(row.state.value)
            XCTAssertFalse(QuotaWindowView.statusLabel(for: row, now: quotaTestNow, language: .english, presentation: .summary).contains("remaining"))
        }
    }
}
