//! Darwin WindowServer/SkyLight bootstrap helpers.
//!
//! This backend intentionally starts at the dynamic-loading boundary: no macOS
//! frameworks are linked at build time.  The private CGS/SkyLight symbols are
//! resolved with std.DynLib so later work can layer a real platform.Surface over
//! whichever WindowServer content path proves viable.

const std = @import("std");
const hal = @import("../hal.zig");
const platform = @import("../platform.zig");

pub const CGError = i32;
pub const CGSConnectionID = u32;
pub const CGSWindowID = u32;
pub const CGSRegionRef = ?*anyopaque;
pub const CFStringRef = ?*anyopaque;
pub const CFTypeRef = ?*anyopaque;

/// The stable-enough private entry points needed to create and configure a
/// WindowServer-side window.  They are deliberately loaded, not linked.
pub const SkyLightApi = struct {
    lib: std.DynLib,
    CGSNewConnection: *const fn (callback: ?*const anyopaque, connection: *CGSConnectionID) callconv(.c) CGError,
    CGSReleaseConnection: ?*const fn (connection: CGSConnectionID) callconv(.c) CGError,
    CGSNewWindow: *const fn (
        connection: CGSConnectionID,
        type_: i32,
        x: f32,
        y: f32,
        region: CGSRegionRef,
        window: *CGSWindowID,
    ) callconv(.c) CGError,
    CGSReleaseWindow: ?*const fn (connection: CGSConnectionID, window: CGSWindowID) callconv(.c) CGError,
    CGSSetWindowProperty: ?*const fn (
        connection: CGSConnectionID,
        window: CGSWindowID,
        key: CFStringRef,
        value: CFTypeRef,
    ) callconv(.c) CGError,

    pub fn close(self: *SkyLightApi) void {
        self.lib.close();
        self.* = undefined;
    }
};

pub const LoadError = error{
    MissingRequiredSymbol,
} || std.DynLib.Error;

const skylight_paths = [_][:0]const u8{
    "/System/Library/PrivateFrameworks/SkyLight.framework/SkyLight",
    "/System/Library/Frameworks/ApplicationServices.framework/Frameworks/CoreGraphics.framework/CoreGraphics",
};

/// Load SkyLight/CoreGraphics private CGS symbols without a link-time framework
/// dependency.  The returned object owns the DynLib handle and must be closed.
pub fn loadSkyLight() LoadError!SkyLightApi {
    var first_err: ?std.DynLib.Error = null;
    inline for (skylight_paths) |path| {
        var lib = std.DynLib.openZ(path.ptr) catch |err| {
            if (first_err == null) first_err = err;
            continue;
        };
        errdefer lib.close();

        const new_connection = lib.lookup(*const fn (?*const anyopaque, *CGSConnectionID) callconv(.c) CGError, "CGSNewConnection") orelse return error.MissingRequiredSymbol;
        const new_window = lib.lookup(*const fn (CGSConnectionID, i32, f32, f32, CGSRegionRef, *CGSWindowID) callconv(.c) CGError, "CGSNewWindow") orelse return error.MissingRequiredSymbol;

        return .{
            .lib = lib,
            .CGSNewConnection = new_connection,
            .CGSReleaseConnection = lib.lookup(*const fn (CGSConnectionID) callconv(.c) CGError, "CGSReleaseConnection"),
            .CGSNewWindow = new_window,
            .CGSReleaseWindow = lib.lookup(*const fn (CGSConnectionID, CGSWindowID) callconv(.c) CGError, "CGSReleaseWindow"),
            .CGSSetWindowProperty = lib.lookup(*const fn (CGSConnectionID, CGSWindowID, CFStringRef, CFTypeRef) callconv(.c) CGError, "CGSSetWindowProperty"),
        };
    }
    return first_err orelse error.FileNotFound;
}

/// Conservative smoke test for the dynamic boundary.  It does not create a
/// WindowServer object; that belongs in the real present backend once content
/// attachment is understood.
pub fn canLoadSkyLight() bool {
    var api = loadSkyLight() catch return false;
    api.close();
    return true;
}

const HeadlessDarwinSurface = struct {
    gpa: std.mem.Allocator,
    bytes: []u8,
    width: u32,
    height: u32,
    stride: u32,
    committed: bool = false,

    fn currentBuffer(ptr: *anyopaque) hal.Error!platform.Buffer {
        const self: *HeadlessDarwinSurface = @ptrCast(@alignCast(ptr));
        return .{
            .bytes = self.bytes,
            .width = self.width,
            .height = self.height,
            .stride = self.stride,
            .format = .bgra8_unorm,
        };
    }

    fn commit(ptr: *anyopaque) hal.Error!void {
        const self: *HeadlessDarwinSurface = @ptrCast(@alignCast(ptr));
        self.committed = true;
    }

    fn processEvents(ptr: *anyopaque) hal.Error!platform.WindowEvent {
        _ = ptr;
        return .none;
    }

    fn size(ptr: *anyopaque) [2]u32 {
        const self: *HeadlessDarwinSurface = @ptrCast(@alignCast(ptr));
        return .{ self.width, self.height };
    }

    fn deinit(ptr: *anyopaque) void {
        const self: *HeadlessDarwinSurface = @ptrCast(@alignCast(ptr));
        self.gpa.free(self.bytes);
        self.gpa.destroy(self);
    }

    const vtable = platform.Surface.VTable{
        .currentBuffer = &currentBuffer,
        .commit = &commit,
        .processEvents = &processEvents,
        .size = &size,
        .deinit = &deinit,
    };
};

const DarwinDisplay = struct {
    gpa: std.mem.Allocator,

    fn createSurface(ptr: *anyopaque, desc: platform.SurfaceDesc) hal.Error!platform.Surface {
        const self: *DarwinDisplay = @ptrCast(@alignCast(ptr));
        const stride = desc.width * 4;
        const byte_count = @as(usize, stride) * desc.height;
        const bytes = self.gpa.alloc(u8, byte_count) catch return error.OutOfMemory;
        errdefer self.gpa.free(bytes);
        @memset(bytes, 0);

        const s = self.gpa.create(HeadlessDarwinSurface) catch return error.OutOfMemory;
        s.* = .{
            .gpa = self.gpa,
            .bytes = bytes,
            .width = desc.width,
            .height = desc.height,
            .stride = stride,
        };
        return .{ .ptr = s, .vtable = &HeadlessDarwinSurface.vtable };
    }

    fn deinit(ptr: *anyopaque) void {
        const self: *DarwinDisplay = @ptrCast(@alignCast(ptr));
        self.gpa.destroy(self);
    }

    const vtable = platform.Display.VTable{
        .createSurface = &createSurface,
        .deinit = &deinit,
    };
};

/// Temporary Darwin display constructor for exercising the software-present path
/// before WindowServer content commit is wired.  It returns BGRA buffers to match
/// the expected macOS compositor byte order and to reuse the existing software
/// RGBA->BGRA present blit.
pub fn create(gpa: std.mem.Allocator) hal.Error!platform.Display {
    const d = gpa.create(DarwinDisplay) catch return error.OutOfMemory;
    d.* = .{ .gpa = gpa };
    return .{ .ptr = d, .vtable = &DarwinDisplay.vtable };
}

test "Darwin dynamic loader resolves or cleanly fails" {
    if (@import("builtin").target.os.tag != .macos) return;
    var api = loadSkyLight() catch |err| switch (err) {
        error.FileNotFound, error.MissingRequiredSymbol => return,
        else => return err,
    };
    defer api.close();
}

test "Darwin display exposes BGRA software-present buffer" {
    const gpa = std.testing.allocator;
    const display = try create(gpa);
    defer display.deinit();

    var surf = try display.createSurface(.{ .width = 4, .height = 3 });
    defer surf.deinit();

    const buf = try surf.currentBuffer();
    try std.testing.expectEqual(@as(u32, 4), buf.width);
    try std.testing.expectEqual(@as(u32, 3), buf.height);
    try std.testing.expectEqual(@as(u32, 16), buf.stride);
    try std.testing.expectEqual(hal.Format.bgra8_unorm, buf.format);
    try surf.commit();
}
