const std = @import("std");
const RecursiveReal = @import("RecursiveReal.zig");
const Rational = @import("Rational.zig");

pub const Number = union(enum) {
    rational: Rational,
    real: RecursiveReal,
};
