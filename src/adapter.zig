const std = @import("std");
const testing = std.testing;
const ChainedStructOut = @import("types.zig").ChainedStructOut;
const Device = @import("device.zig").Device;
const FeatureName = @import("types.zig").FeatureName;
const SupportedLimits = @import("types.zig").SupportedLimits;
const RequestDeviceStatus = @import("types.zig").RequestDeviceStatus;
const BackendType = @import("types.zig").BackendType;
const RequestDeviceCallback = @import("callbacks.zig").RequestDeviceCallback;
const Impl = @import("interface.zig").Impl;

pub const Adapter = opaque {
    pub const Type = enum(u32) {
        discrete_gpu,
        integrated_gpu,
        cpu,
        unknown,

        pub fn name(t: Type) []const u8 {
            return switch (t) {
                .discrete_gpu => "Discrete GPU",
                .integrated_gpu => "Integrated GPU",
                .cpu => "CPU",
                .unknown => "Unknown",
            };
        }
    };

    pub const Properties = extern struct {
        next_in_chain: ?*ChainedStructOut = null,
        vendor_id: u32,
        vendor_name: [*:0]const u8,
        architecture: [*:0]const u8,
        device_id: u32,
        name: [*:0]const u8,
        driver_description: [*:0]const u8,
        adapter_type: Type,
        backend_type: BackendType,
    };

    pub inline fn createDevice(adapter: *Adapter, descriptor: ?*const Device.Descriptor) ?*Device {
        return Impl.adapterCreateDevice(adapter, descriptor);
    }

    /// Call once with null to determine the array length, and again to fetch the feature list.
    ///
    /// Consider using the enumerateFeaturesOwned helper.
    pub inline fn enumerateFeatures(adapter: *Adapter, features: ?[*]FeatureName) usize {
        return Impl.adapterEnumerateFeatures(adapter, features);
    }

    /// Enumerates the adapter features, storing the result in an allocated slice which is owned by
    /// the caller.
    pub inline fn enumerateFeaturesOwned(adapter: *Adapter, allocator: std.mem.Allocator) ![]FeatureName {
        const count = adapter.enumerateFeatures(null);
        var data = try allocator.alloc(FeatureName, count);
        _ = adapter.enumerateFeatures(data.ptr);
        return data;
    }

    pub inline fn getLimits(adapter: *Adapter, limits: *SupportedLimits) bool {
        return Impl.adapterGetLimits(adapter, limits);
    }

    pub inline fn getProperties(adapter: *Adapter, properties: *Adapter.Properties) void {
        Impl.adapterGetProperties(adapter, properties);
    }

    pub inline fn hasFeature(adapter: *Adapter, feature: FeatureName) bool {
        return Impl.adapterHasFeature(adapter, feature);
    }

    pub inline fn requestDevice(
        adapter: *Adapter,
        descriptor: ?*const Device.Descriptor,
        comptime Context: type,
        comptime callback: fn (
            status: RequestDeviceStatus,
            device: *Device,
            message: ?[*:0]const u8,
            ctx: Context,
        ) callconv(.Inline) void,
        context: Context,
    ) void {
        const c_callback = struct {
            pub fn callback(status: RequestDeviceStatus, device: *Device, message: ?[*:0]const u8, userdata: ?*anyopaque) void {
                callback(
                    status,
                    device,
                    message,
                    if (Context == void) {} orelse @ptrCast(Context, userdata),
                );
            }
        };
        Impl.adapterRequestDevice(adapter, descriptor, c_callback, if (Context == void) null orelse context);
    }

    pub inline fn reference(adapter: *Adapter) void {
        Impl.adapterReference(adapter);
    }

    pub inline fn release(adapter: *Adapter) void {
        Impl.adapterRelease(adapter);
    }
};

test "Adapter.Type name" {
    try testing.expectEqualStrings("Discrete GPU", Adapter.Type.discrete_gpu.name());
}
