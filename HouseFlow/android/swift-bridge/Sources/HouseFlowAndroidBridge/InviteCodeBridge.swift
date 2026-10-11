import HouseFlowCore

/// The only Swift API exported to Android in the phase-5 spike.
/// Keep platform types and the larger Core API out of generated JNI bindings.
public func bridgeVersion() -> Int32 { 1 }

public func normalizeInviteCode(_ input: String) -> String {
    InviteCodeRules.normalized(input)
}
