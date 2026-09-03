import ProofForge.Cli

namespace Tests.CliSpec

-- build: names + --out; --target omitted (SVM default)
#guard
  match ProofForge.Cli.parseArgs ["build", "Counter", "--out", "build/tmp"] with
  | .ok o =>
      o.command == .build && o.outDir.toString == "build/tmp" && o.names == #["Counter"]
  | .error _ => false

-- build: multiple names, --out, --target svm accepted
#guard
  match ProofForge.Cli.parseArgs ["build", "Counter", "Pair", "--out", "out", "--target", "svm"] with
  | .ok o =>
      o.command == .build && o.outDir.toString == "out" && o.names == #["Counter", "Pair"]
  | .error _ => false

-- --target svm with no names
#guard
  match ProofForge.Cli.parseArgs ["build", "--target", "svm"] with
  | .ok o => o.command == .build && o.names.isEmpty
  | .error _ => false

-- --target solana / sbpf accepted (SVM aliases)
#guard
  match ProofForge.Cli.parseArgs ["build", "--target", "solana", "Counter"] with
  | .ok o => o.command == .build && o.names == #["Counter"]
  | .error _ => false

#guard
  match ProofForge.Cli.parseArgs ["build", "--target", "sbpf", "Counter"] with
  | .ok o => o.command == .build && o.names == #["Counter"]
  | .error _ => false

-- original SVM path: --target svm --out
#guard
  match ProofForge.Cli.parseArgs ["build", "--target", "svm", "--out", "build/sbpf", "Counter"] with
  | .ok o => o.outDir.toString == "build/sbpf" && o.names == #["Counter"]
  | .error _ => false

-- --module repeatable
#guard
  match ProofForge.Cli.parseArgs
      ["build", "--module", "MyContract.Counter", "--module", "MyContract.Pair"] with
  | .ok o => o.modules == #["MyContract.Counter", "MyContract.Pair"] && o.names.isEmpty
  | .error _ => false

-- init name capture
#guard
  match ProofForge.Cli.parseArgs ["init", "demo"] with
  | .ok o => o.command == .init && o.initName == "demo"
  | .error _ => false

-- --help / --version
#guard
  match ProofForge.Cli.parseArgs ["--help"] with
  | .ok o => o.help == true
  | .error _ => false

#guard
  match ProofForge.Cli.parseArgs ["build", "-h"] with
  | .ok o => o.help == true
  | .error _ => false

#guard
  match ProofForge.Cli.parseArgs ["--version"] with
  | .ok o => o.version == true
  | .error _ => false

#guard
  match ProofForge.Cli.parseArgs ["-V"] with
  | .ok o => o.version == true
  | .error _ => false

-- unknown flag
#guard
  match ProofForge.Cli.parseArgs ["build", "--foo"] with
  | .ok _ => false
  | .error e => e == "unknown flag --foo"

-- non-SVM --target is an error
#guard
  match ProofForge.Cli.parseArgs ["build", "--target", "evm", "--out", "out", "Counter"] with
  | .ok _ => false
  | .error e => e == "unknown target evm (this build of pf supports SVM only)"

#guard
  match ProofForge.Cli.parseArgs ["build", "--target", "near"] with
  | .ok _ => false
  | .error e => e == "unknown target near (this build of pf supports SVM only)"

#guard
  match ProofForge.Cli.parseArgs ["build", "--target", "xrpl"] with
  | .ok _ => false
  | .error e => e == "unknown target xrpl (this build of pf supports SVM only)"

#guard
  match ProofForge.Cli.parseArgs ["build", "--target", "wasm"] with
  | .ok _ => false
  | .error e => e == "unknown target wasm (this build of pf supports SVM only)"

#guard
  match ProofForge.Cli.parseArgs ["build", "--target", "xrpl-alphanet", "XrplSmoke"] with
  | .ok _ => false
  | .error e => e == "unknown target xrpl-alphanet (this build of pf supports SVM only)"

-- deploy/call are no longer commands: first token is a program name under build
#guard
  match ProofForge.Cli.parseArgs ["deploy", "XrplSmoke"] with
  | .ok o => o.command == .build && o.names == #["deploy", "XrplSmoke"]
  | .error _ => false

#guard
  match ProofForge.Cli.parseArgs ["call", "bump"] with
  | .ok o => o.command == .build && o.names == #["call", "bump"]
  | .error _ => false

-- SVM fixture mapping (no target argument)
#guard ProofForge.Cli.svmModuleName "Phoenix" == `Examples.Svm.Phoenix
#guard ProofForge.Cli.svmModuleName "Counter" == `Examples.Counter
#guard ProofForge.Cli.fixtureModule "Counter" == `Examples.Counter
#guard ProofForge.Cli.fixtureModule "Phoenix" == `Examples.Svm.Phoenix
#guard ProofForge.Cli.fixtureModule "TokenShape" == `Examples.TokenShape
#guard ProofForge.Cli.fixtureModule "SvmExceptErgonomics" == `Examples.SvmExceptErgonomics

end Tests.CliSpec
