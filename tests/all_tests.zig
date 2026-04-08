//! Aggregator that pulls in every test file. The build.zig wires this
//! single module into a `zig build test` step.

comptime {
    _ = @import("mem_test.zig");
    _ = @import("json_test.zig");
    _ = @import("flare_action_test.zig");
    _ = @import("request_test.zig");
    _ = @import("response_test.zig");
    _ = @import("log_test.zig");
    _ = @import("time_test.zig");
    _ = @import("spark_test.zig");
    _ = @import("plasma_test.zig");
    _ = @import("secrets_test.zig");
    _ = @import("crypto_test.zig");
    _ = @import("encoding_test.zig");
    _ = @import("id_test.zig");
    _ = @import("beam_test.zig");
    _ = @import("ws_test.zig");
}
