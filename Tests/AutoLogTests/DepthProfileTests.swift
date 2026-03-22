import AutoLog
import Testing

@Suite
struct DepthProfileTests {

    @Test func mvvmView_returnsDepth1() {
        let profile = DepthProfile.mvvm
        #expect(profile.depth(for: "ContentView") == 1)
    }

    @Test func mvvmViewModel_returnsDepth2() {
        let profile = DepthProfile.mvvm
        #expect(profile.depth(for: "LoggingDemoViewModel") == 2)
    }

    @Test func mvvmModel_returnsDepth3() {
        let profile = DepthProfile.mvvm
        #expect(profile.depth(for: "AccountModel") == 3)
    }

    @Test func mvvmService_returnsDepth3() {
        let profile = DepthProfile.mvvm
        #expect(profile.depth(for: "UserService") == 3)
    }

    @Test func unknownSuffix_returnsNil() {
        let profile = DepthProfile.mvvm
        #expect(profile.depth(for: "SomethingUnknown") == nil)
    }

    @Test func viewModel_matchesBefore_model() {
        // "ViewModel" is longer than "Model", so it wins regardless of array order
        let profile = DepthProfile.mvvm
        #expect(profile.depth(for: "MyViewModel") == 2)
    }

    @Test func arrowDepth1_isSingleArrow() {
        let profile = DepthProfile.mvvm
        #expect(profile.arrow(for: "ContentView") == "->")
    }

    @Test func arrowDepth2_isDoubleArrow() {
        let profile = DepthProfile.mvvm
        #expect(profile.arrow(for: "LoggingDemoViewModel") == "-->")
    }

    @Test func arrowUnknown_defaultsToSingleArrow() {
        let profile = DepthProfile.mvvm
        #expect(profile.arrow(for: "SomethingUnknown") == "->")
    }

    @Test func customProfile_usesProvidedDepths() {
        let profile = DepthProfile(suffixDepths: [("Screen", 1), ("Worker", 3)])
        #expect(profile.depth(for: "HomeScreen") == 1)
        #expect(profile.depth(for: "FetchWorker") == 3)
        #expect(profile.depth(for: "UnknownThing") == nil)
    }

    @Test func cleanArchitecture_useCase_returnsDepth3() {
        let profile = DepthProfile.cleanArchitecture
        #expect(profile.depth(for: "FetchUserUseCase") == 3)
    }

    @Test func cleanArchitecture_repository_returnsDepth4() {
        let profile = DepthProfile.cleanArchitecture
        #expect(profile.depth(for: "UserRepository") == 4)
    }
}
