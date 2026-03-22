import AutoLog

extension Omittable where Self == Omit {
  static var mock: any Omittable {
    Omit.parameter("mock")
  }
}
