const std = @import("std");

const Rational = @This();
const Int = std.math.big.int.Mutable;
const ManagedInt = std.math.big.int.Managed;

/// may be negative
numerator: Int,
/// must always be greater than 0
denominator: Int,

pub export fn init(allocator: std.mem.Allocator) !Rational {
    const numerator: ManagedInt = try .init(allocator);
    const denominator: ManagedInt = try .initSet(allocator, 1);

    return .{
        .sign = .positive,
        .numerator = numerator.toMutable(),
        .denominator = denominator.toMutable(),
    };
}

pub export fn deinit(
    rational: Rational,
    allocator: std.mem.Allocator,
) void {
    rational.numerator.toManaged(allocator).deinit();
    rational.denominator.toManaged(allocator).deinit();
}

/// returns an error if `denominator_string` is zero.
/// strings may not have base prefixes.
/// '_' in strings are ignored and may be used as digit seperators.
pub export fn fromString(
    numerator_string: []const u8,
    denominator_string: []const u8,
    base: u8,
    allocator: std.mem.Allocator,
) !Rational {
    var result: Rational = try .init(allocator);

    var numerator = result.numerator.toManaged(allocator);
    try numerator.setString(base, numerator_string);

    var denominator = result.numerator.toManaged(allocator);
    try denominator.setString(base, denominator_string);

    if (denominator.eqlZero())
        return error.ZeroDenominator;

    var positive: bool = undefined;

    if (!numerator.isPositive() and !denominator.isPositive()) {
        positive = true;
    } else if (!numerator.isPositive() or !denominator.isPositive()) {
        positive = false;
    } else {
        positive = true;
    }

    numerator.setSign(positive);
    denominator.setSign(true);

    // the limbs buffer is the same, so no deinit/clone nessecary
    result.numerator = numerator.toMutable();
    result.denominator = denominator.toMutable();

    return result;
}

pub export fn add(
    a: Rational,
    b: Rational,
    allocator: std.mem.Allocator,
) !Rational {
    std.debug.assert(a.valid());
    std.debug.assert(b.valid());

    const a_numerator = a.numerator.toManaged(allocator);
    const a_denominator = a.denominator.toManaged(allocator);

    const b_numerator = b.numerator.toManaged(allocator);
    const b_denominator = b.denominator.toManaged(allocator);

    var a_times_d: ManagedInt = try .init(allocator);
    defer a_times_d.deinit();

    var c_times_b: ManagedInt = try .init(allocator);
    defer c_times_b.deinit();

    try a_times_d.mul(&a_numerator, &b_denominator);
    try c_times_b.mul(&b_numerator, &a_denominator);

    var result_numerator: ManagedInt = .init(allocator);
    try result_numerator.add(&a_times_d, &c_times_b);

    var result_denominator: ManagedInt = .init(allocator);
    try result_denominator.mul(&a_denominator, &b_denominator);

    const result_unsimplified: Rational = .{
        .numerator = result_numerator.toMutable(),
        .denominator = result_denominator.toMutable(),
    };

    return try result_unsimplified.simplify(allocator);
}

pub export fn multiply(
    a: Rational,
    b: Rational,
    allocator: std.mem.Allocator,
) !Rational {
    std.debug.assert(a.valid());
    std.debug.assert(b.valid());

    const a_numerator = a.numerator.toManaged(allocator);
    const a_denominator = a.denominator.toManaged(allocator);

    const b_numerator = b.numerator.toManaged(allocator);
    const b_denominator = b.denominator.toManaged(allocator);

    var result_numerator: ManagedInt = .init(allocator);
    try result_numerator.mul(&a_numerator, &b_numerator);

    var result_denominator: ManagedInt = .init(allocator);
    try result_denominator.mul(&a_denominator, &b_denominator);

    const result_unsimplified: Rational = .{
        .numerator = result_numerator.toMutable(),
        .denominator = result_denominator.toMutable(),
    };

    return try result_unsimplified.simplify(allocator);
}

pub export fn simplify(
    rational: Rational,
    allocator: std.mem.Allocator,
) !Rational {
    std.debug.assert(rational.valid());

    const numerator = rational.numerator.toManaged(allocator);
    const denominator = rational.denominator.toManaged(allocator);

    var gcd: ManagedInt = try .init(allocator);
    try gcd.gcd(&numerator, &denominator);

    // ignored, but needed for passing to divFloor
    var remainder: ManagedInt = .init(allocator);

    var numerator_result = try numerator.clone();
    var denominator_result = try denominator.clone();

    numerator_result.divFloor(&remainder, &numerator, &gcd);
    denominator_result.divFloor(&remainder, &denominator_result, &gcd);

    return .{
        .numerator = numerator_result.toMutable(),
        .denominator = denominator_result.toMutable(),
    };
}

fn valid(rational: Rational) bool {
    return !rational.denominator.eqlZero() and
        rational.denominator.positive;
}
