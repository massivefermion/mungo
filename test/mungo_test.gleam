import gleeunit
import gleeunit/should

pub fn main() {
  gleeunit.main()
}

pub fn stub_mungo_test() {
  "mungo"
  |> should.equal("mungo")
}
