//! Darwin WindowServer/SkyLight platform backend.
//!
//! Provides a platform.Display and platform.Surface implementation on Darwin systems
//! (both real macOS and Darwin-compatible kernels implementing WindowServer/IOKit).
//!
//! Uses dynamic loading via std.DynLib so Prism does not link macOS frameworks at
//! build time, preserving the no-C-dependencies architecture. Resolves both modern
//! SLS* (SkyLight Services) and legacy CGS* (CoreGraphics Services) symbols to
//! support standard macOS releases and custom WindowServer implementations.

const std = @import("std");
const hal = @import("../hal.zig");
const platform = @import("../platform.zig");

pub const CGError = i32;
pub const kCGErrorSuccess: CGError = 0;
pub const kCGErrorFailure: CGError = 1000;
pub const kCGErrorIllegalArgument: CGError = 1001;
pub const kCGErrorInvalidConnection: CGError = 1002;

pub const CGSConnectionID = u32;
pub const CGSWindowID = u32;
pub const CGSSurfaceID = u32;
pub const CGSRegionRef = ?*anyopaque;
pub const CFStringRef = ?*anyopaque;
pub const CFTypeRef = ?*anyopaque;

pub const CGFloat = f64;

pub const CGPoint = extern struct {
    x: CGFloat,
    y: CGFloat,
};

pub const CGSize = extern struct {
    width: CGFloat,
    height: CGFloat,
};

pub const CGRect = extern struct {
    origin: CGPoint,
    size: CGSize,
};

pub const CGSWindowOrderingMode = enum(i32) {
    orderBelow = -1,
    orderOut = 0,
    orderAbove = 1,

    pub const orderIn = CGSWindowOrderingMode.orderAbove;
};

pub const CGSBackingType = enum(i32) {
    nonRetained = 0,
    retained = 1,
    buffered = 2,
};

/// Resolved SkyLight/CoreGraphics entry points needed to create, configure,
/// and present windows and surfaces with WindowServer.
pub const SkyLightApi = struct {
    lib: std.DynLib,

    // Connection lifecycle
    new_connection: ?*const fn (callback: ?*const anyopaque, connection: *CGSConnectionID) callconv(.c) CGError,
    release_connection: ?*const fn (connection: CGSConnectionID) callconv(.c) CGError,
    main_connection_id: ?*const fn () callconv(.c) CGSConnectionID,

    // Window lifecycle & geometry
    new_window: *const fn (
        connection: CGSConnectionID,
        type_: CGSBackingType,
        x: CGFloat,
        y: CGFloat,
        region: CGSRegionRef,
        window: *CGSWindowID,
    ) callconv(.c) CGError,
    release_window: *const fn (connection: CGSConnectionID, window: CGSWindowID) callconv(.c) CGError,
    order_window: *const fn (
        connection: CGSConnectionID,
        window: CGSWindowID,
        op: i32,
        relativeTo: CGSWindowID,
    ) callconv(.c) CGError,
    set_window_shape: ?*const fn (
        connection: CGSConnectionID,
        window: CGSWindowID,
        x_offset: f32,
        y_offset: f32,
        shape: CGSRegionRef,
    ) callconv(.c) CGError,
    set_window_level: ?*const fn (connection: CGSConnectionID, window: CGSWindowID, level: i32) callconv(.c) CGError,
    set_window_property: ?*const fn (
        connection: CGSConnectionID,
        window: CGSWindowID,
        key: CFStringRef,
        value: CFTypeRef,
    ) callconv(.c) CGError,

    // Surface management
    add_surface: *const fn (connection: CGSConnectionID, window: CGSWindowID, surface: *CGSSurfaceID) callconv(.c) CGError,
    remove_surface: *const fn (connection: CGSConnectionID, window: CGSWindowID, surface: CGSSurfaceID) callconv(.c) CGError,
    set_surface_bounds: *const fn (connection: CGSConnectionID, window: CGSWindowID, surface: CGSSurfaceID, bounds: CGRect) callconv(.c) CGError,
    new_region: ?*const fn (bounds: *const CGRect, region: *CGSRegionRef) callconv(.c) CGError,
    release_region: ?*const fn (region: CGSRegionRef) callconv(.c) CGError,
    order_surface: ?*const fn (connection: CGSConnectionID, window: CGSWindowID, surface: CGSSurfaceID, other: CGSSurfaceID, place: i32) callconv(.c) CGError,
    set_surface_resolution: ?*const fn (connection: CGSConnectionID, window: CGSWindowID, surface: CGSSurfaceID, scale: CGFloat) callconv(.c) CGError,
    set_surface_opacity: ?*const fn (connection: CGSConnectionID, window: CGSWindowID, surface: CGSSurfaceID, isOpaque: bool) callconv(.c) CGError,

    // Buffer flush & synchronization
    flush_surface: ?*const fn (connection: CGSConnectionID, window: CGSWindowID, surface: CGSSurfaceID, param: i32) callconv(.c) CGError,
    flush_window: ?*const fn (connection: CGSConnectionID, window: CGSWindowID, flush_region: CGSRegionRef) callconv(.c) CGError,

    // WindowServer events
    get_event_port: ?*const fn (connection: CGSConnectionID, port: *u32) callconv(.c) CGError,

    pub fn close(self: *SkyLightApi) void {
        self.lib.close();
        self.* = undefined;
    }
};

pub const LoadError = error{
    FileNotFound,
    MissingRequiredSymbol,
} || std.DynLib.Error;

const skylight_paths = [_][:0]const u8{
    "/System/Library/PrivateFrameworks/SkyLight.framework/SkyLight",
    "/System/Library/Frameworks/ApplicationServices.framework/Frameworks/CoreGraphics.framework/CoreGraphics",
    "libSkyLight.dylib",
    "SkyLight",
    "/usr/lib/libSkyLight.dylib",
    "/usr/local/lib/libSkyLight.dylib",
};

fn lookupSymbol(lib: *std.DynLib, comptime T: type, comptime sls_name: [:0]const u8, comptime cgs_name: [:0]const u8) ?T {
    return lib.lookup(T, sls_name) orelse lib.lookup(T, cgs_name);
}

/// Load SkyLight / CoreGraphics private symbols without link-time dependencies.
/// Tries modern SLS* names first, then falls back to CGS* aliases.
pub fn loadSkyLight() LoadError!SkyLightApi {
    var first_err: ?std.DynLib.Error = null;
    for (skylight_paths) |path| {
        var lib = std.DynLib.openZ(path.ptr) catch |err| {
            if (first_err == null) first_err = err;
            continue;
        };
        errdefer lib.close();

        const new_conn = lookupSymbol(&lib, *const fn (?*const anyopaque, *CGSConnectionID) callconv(.c) CGError, "SLSNewConnection", "CGSNewConnection");
        const main_conn = lookupSymbol(&lib, *const fn () callconv(.c) CGSConnectionID, "SLSMainConnectionID", "CGSMainConnectionID");
        if (new_conn == null and main_conn == null) return error.MissingRequiredSymbol;

        const new_win = lookupSymbol(&lib, *const fn (CGSConnectionID, CGSBackingType, CGFloat, CGFloat, CGSRegionRef, *CGSWindowID) callconv(.c) CGError, "SLSNewWindow", "CGSNewWindow") orelse return error.MissingRequiredSymbol;
        const rel_win = lookupSymbol(&lib, *const fn (CGSConnectionID, CGSWindowID) callconv(.c) CGError, "SLSReleaseWindow", "CGSReleaseWindow") orelse return error.MissingRequiredSymbol;
        const ord_win = lookupSymbol(&lib, *const fn (CGSConnectionID, CGSWindowID, i32, CGSWindowID) callconv(.c) CGError, "SLSOrderWindow", "CGSOrderWindow") orelse return error.MissingRequiredSymbol;
        const add_surf = lookupSymbol(&lib, *const fn (CGSConnectionID, CGSWindowID, *CGSSurfaceID) callconv(.c) CGError, "SLSAddSurface", "CGSAddSurface") orelse return error.MissingRequiredSymbol;
        const rem_surf = lookupSymbol(&lib, *const fn (CGSConnectionID, CGSWindowID, CGSSurfaceID) callconv(.c) CGError, "SLSRemoveSurface", "CGSRemoveSurface") orelse return error.MissingRequiredSymbol;
        const set_surf_bounds = lookupSymbol(&lib, *const fn (CGSConnectionID, CGSWindowID, CGSSurfaceID, CGRect) callconv(.c) CGError, "SLSSetSurfaceBounds", "CGSSetSurfaceBounds") orelse return error.MissingRequiredSymbol;

        return .{
            .lib = lib,
            .new_connection = new_conn,
            .release_connection = lookupSymbol(&lib, *const fn (CGSConnectionID) callconv(.c) CGError, "SLSReleaseConnection", "CGSReleaseConnection"),
            .main_connection_id = main_conn,
            .new_window = new_win,
            .release_window = rel_win,
            .order_window = ord_win,
            .set_window_shape = lookupSymbol(&lib, *const fn (CGSConnectionID, CGSWindowID, f32, f32, CGSRegionRef) callconv(.c) CGError, "SLSSetWindowShape", "CGSSetWindowShape"),
            .set_window_level = lookupSymbol(&lib, *const fn (CGSConnectionID, CGSWindowID, i32) callconv(.c) CGError, "SLSSetWindowLevel", "CGSSetWindowLevel"),
            .set_window_property = lookupSymbol(&lib, *const fn (CGSConnectionID, CGSWindowID, CFStringRef, CFTypeRef) callconv(.c) CGError, "SLSSetWindowProperty", "CGSSetWindowProperty"),
            .add_surface = add_surf,
            .remove_surface = rem_surf,
            .set_surface_bounds = set_surf_bounds,
            .new_region = lookupSymbol(&lib, *const fn (*const CGRect, *CGSRegionRef) callconv(.c) CGError, "SLSNewRegionWithRect", "CGSNewRegionWithRect"),
            .release_region = lookupSymbol(&lib, *const fn (CGSRegionRef) callconv(.c) CGError, "SLSReleaseRegion", "CGSReleaseRegion"),
            .order_surface = lookupSymbol(&lib, *const fn (CGSConnectionID, CGSWindowID, CGSSurfaceID, CGSSurfaceID, i32) callconv(.c) CGError, "SLSOrderSurface", "CGSOrderSurface"),
            .set_surface_resolution = lookupSymbol(&lib, *const fn (CGSConnectionID, CGSWindowID, CGSSurfaceID, CGFloat) callconv(.c) CGError, "SLSSetSurfaceResolution", "CGSSetSurfaceResolution"),
            .set_surface_opacity = lookupSymbol(&lib, *const fn (CGSConnectionID, CGSWindowID, CGSSurfaceID, bool) callconv(.c) CGError, "SLSSetSurfaceOpacity", "CGSSetSurfaceOpacity"),
            .flush_surface = lookupSymbol(&lib, *const fn (CGSConnectionID, CGSWindowID, CGSSurfaceID, i32) callconv(.c) CGError, "SLSFlushSurface", "CGSFlushSurface"),
            .flush_window = lookupSymbol(&lib, *const fn (CGSConnectionID, CGSWindowID, CGSRegionRef) callconv(.c) CGError, "SLSFlushWindow", "CGSFlushWindow"),
            .get_event_port = lookupSymbol(&lib, *const fn (CGSConnectionID, *u32) callconv(.c) CGError, "SLSGetEventPort", "CGSGetEventPort"),
        };
    }
    return first_err orelse error.FileNotFound;
}

/// Smoke test predicate checking whether SkyLight or equivalent library can be loaded.
pub fn canLoadSkyLight() bool {
    var api = loadSkyLight() catch return false;
    api.close();
    return true;
}

pub const DarwinSurface = struct {
    gpa: std.mem.Allocator,
    display: *DarwinDisplay,
    wid: CGSWindowID = 0,
    sid: CGSSurfaceID = 0,
    bytes: []u8,
    width: u32,
    height: u32,
    stride: u32,
    committed: bool = false,

    fn currentBuffer(ptr: *anyopaque) hal.Error!platform.Buffer {
        const self: *DarwinSurface = @ptrCast(@alignCast(ptr));
        return .{
            .bytes = self.bytes,
            .width = self.width,
            .height = self.height,
            .stride = self.stride,
            .format = .bgra8_unorm,
        };
    }

    fn commit(ptr: *anyopaque) hal.Error!void {
        const self: *DarwinSurface = @ptrCast(@alignCast(ptr));
        self.committed = true;

        if (self.display.api) |*api| {
            if (self.display.cid != 0) {
                if (self.sid != 0) {
                    if (api.flush_surface) |flush| {
                        _ = flush(self.display.cid, self.wid, self.sid, 0);
                    }
                }
                if (self.wid != 0) {
                    if (api.flush_window) |flush| {
                        _ = flush(self.display.cid, self.wid, null);
                    }
                }
            }
        }
    }

    fn processEvents(ptr: *anyopaque) hal.Error!platform.WindowEvent {
        const self: *DarwinSurface = @ptrCast(@alignCast(ptr));
        _ = self;
        // WindowServer events will be delivered over the Mach event port (display.event_port).
        return .none;
    }

    fn size(ptr: *anyopaque) [2]u32 {
        const self: *DarwinSurface = @ptrCast(@alignCast(ptr));
        return .{ self.width, self.height };
    }

    fn deinit(ptr: *anyopaque) void {
        const self: *DarwinSurface = @ptrCast(@alignCast(ptr));
        if (self.display.api) |*api| {
            if (self.display.cid != 0) {
                if (self.sid != 0) {
                    _ = api.remove_surface(self.display.cid, self.wid, self.sid);
                    self.sid = 0;
                }
                if (self.wid != 0) {
                    _ = api.release_window(self.display.cid, self.wid);
                    self.wid = 0;
                }
            }
        }
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

pub const DarwinDisplay = struct {
    gpa: std.mem.Allocator,
    api: ?SkyLightApi = null,
    cid: CGSConnectionID = 0,
    event_port: u32 = 0,

    fn createSurface(ptr: *anyopaque, desc: platform.SurfaceDesc) hal.Error!platform.Surface {
        const self: *DarwinDisplay = @ptrCast(@alignCast(ptr));
        const stride = desc.width * 4;
        const byte_count = @as(usize, stride) * desc.height;
        const bytes = self.gpa.alloc(u8, byte_count) catch return error.OutOfMemory;
        errdefer self.gpa.free(bytes);
        @memset(bytes, 0);

        var wid: CGSWindowID = 0;
        var sid: CGSSurfaceID = 0;

        if (self.api) |*api| {
            if (self.cid != 0) {
                const bounds = CGRect{
                    .origin = .{ .x = 0, .y = 0 },
                    .size = .{
                        .width = @floatFromInt(desc.width),
                        .height = @floatFromInt(desc.height),
                    },
                };

                // CGSNewWindow requires a region describing the window's initial
                // shape; passing null fails with kCGErrorFailure on modern macOS.
                var region: CGSRegionRef = null;
                if (api.new_region) |new_region| {
                    if (new_region(&bounds, &region) != kCGErrorSuccess) region = null;
                }
                defer if (region) |r| {
                    if (api.release_region) |release| _ = release(r);
                };

                if (api.new_window(self.cid, .buffered, 0.0, 0.0, region, &wid) == kCGErrorSuccess) {
                    if (api.set_window_level) |set_level| {
                        _ = set_level(self.cid, wid, 0);
                    }

                    if (api.add_surface(self.cid, wid, &sid) == kCGErrorSuccess) {
                        if (api.set_surface_bounds(self.cid, wid, sid, bounds) == kCGErrorSuccess) {
                            if (api.order_surface) |order_surf| {
                                _ = order_surf(self.cid, wid, sid, 0, 1);
                            }
                            _ = api.order_window(self.cid, wid, @backingInt(CGSWindowOrderingMode.orderAbove), 0);
                        } else {
                            _ = api.remove_surface(self.cid, wid, sid);
                            sid = 0;
                        }
                    }

                    if (sid == 0) {
                        _ = api.release_window(self.cid, wid);
                        wid = 0;
                    }
                } else {
                    wid = 0;
                }
            }
        }
        errdefer if (self.api) |*api| {
            if (self.cid != 0) {
                if (sid != 0) _ = api.remove_surface(self.cid, wid, sid);
                if (wid != 0) _ = api.release_window(self.cid, wid);
            }
        };

        const s = self.gpa.create(DarwinSurface) catch return error.OutOfMemory;
        s.* = .{
            .gpa = self.gpa,
            .display = self,
            .wid = wid,
            .sid = sid,
            .bytes = bytes,
            .width = desc.width,
            .height = desc.height,
            .stride = stride,
        };
        return .{ .ptr = s, .vtable = &DarwinSurface.vtable };
    }

    fn deinit(ptr: *anyopaque) void {
        const self: *DarwinDisplay = @ptrCast(@alignCast(ptr));
        if (self.api) |*api| {
            if (self.cid != 0) {
                if (api.release_connection) |rel_conn| {
                    _ = rel_conn(self.cid);
                }
                self.cid = 0;
            }
            api.close();
            self.api = null;
        }
        self.gpa.destroy(self);
    }

    const vtable = platform.Display.VTable{
        .createSurface = &createSurface,
        .deinit = &deinit,
    };
};

/// Create a Darwin platform display. Connects to WindowServer via SkyLight if available,
/// or operates in headless/software mode if WindowServer is not running or absent.
pub fn create(gpa: std.mem.Allocator) hal.Error!platform.Display {
    const d = gpa.create(DarwinDisplay) catch return error.OutOfMemory;
    d.* = .{ .gpa = gpa };

    if (loadSkyLight()) |api| {
        d.api = api;
        var cid: CGSConnectionID = 0;
        if (api.new_connection) |nc| {
            if (nc(null, &cid) == kCGErrorSuccess) {
                d.cid = cid;
            }
        } else if (api.main_connection_id) |mc| {
            d.cid = mc();
        }

        if (d.cid != 0 and api.get_event_port != null) {
            var port: u32 = 0;
            if (api.get_event_port.?(d.cid, &port) == kCGErrorSuccess) {
                d.event_port = port;
            }
        }
    } else |_| {
        // When SkyLight is absent (e.g. headless tests or non-GUI environments),
        // d.api remains null and createSurface gracefully provides software buffers.
    }

    return .{ .ptr = d, .vtable = &DarwinDisplay.vtable };
}

test "Darwin types and enums layout match macOS ABI" {
    try std.testing.expectEqual(@as(i32, 0), kCGErrorSuccess);
    try std.testing.expectEqual(@as(i32, 1), @backingInt(CGSWindowOrderingMode.orderAbove));
    try std.testing.expectEqual(@as(i32, -1), @backingInt(CGSWindowOrderingMode.orderBelow));
    try std.testing.expectEqual(@as(i32, 0), @backingInt(CGSWindowOrderingMode.orderOut));
    try std.testing.expectEqual(@as(i32, 2), @backingInt(CGSBackingType.buffered));

    const rect = CGRect{
        .origin = .{ .x = 10.0, .y = 20.0 },
        .size = .{ .width = 100.0, .height = 200.0 },
    };
    try std.testing.expectEqual(@as(CGFloat, 10.0), rect.origin.x);
    try std.testing.expectEqual(@as(CGFloat, 200.0), rect.size.height);
}

test "Darwin dynamic loader resolves or cleanly fails" {
    if (!@import("builtin").target.os.tag.isDarwin()) return;
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
