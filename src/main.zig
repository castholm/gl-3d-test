const std = @import("std");
const glfw = @import("glfw");
const gl = @import("gl");
const zmath = @import("zmath");

const model = @import("models/f.zig");

var window: glfw.Window = undefined;
const window_width = 640;
const window_height = 480;

const keyboard = struct {
    const KeySet = std.EnumSet(glfw.Key);

    var previous = KeySet.initEmpty();
    var current = KeySet.initEmpty();

    fn glfwKeyCallback(_: glfw.Window, key: glfw.Key, _: i32, action: glfw.Action, _: glfw.Mods) void {
        switch (action) {
            .release => current.remove(key),
            .press => current.insert(key),
            else => {},
        }
    }
};

pub fn main() !void {
    glfw.setErrorCallback(struct {
        fn callback(error_code: glfw.ErrorCode, description: [:0]const u8) void {
            std.log.err("glfw: {}: {s}", .{ error_code, description });
        }
    }.callback);

    if (!glfw.init(.{})) return error.InitFailed;
    defer glfw.terminate();

    window = glfw.Window.create(window_width, window_height, "GL", null, null, .{
        .context_version_major = gl.api.version_major,
        .context_version_minor = gl.api.version_minor,
        .opengl_profile = .opengl_core_profile,
        .opengl_forward_compat = true,
        .resizable = false,
    }) orelse return error.InitFailed;
    defer window.destroy();

    window.setKeyCallback(keyboard.glfwKeyCallback);
    defer window.setKeyCallback(null);

    glfw.makeContextCurrent(window);
    defer glfw.makeContextCurrent(null);

    try gl.init(struct {
        pub fn getCommandFnPtr(_: @This(), command_name: [:0]const u8) !?glfw.GLProc {
            return glfw.getProcAddress(command_name);
        }
        pub fn extensionSupported(_: @This(), extension_name: [:0]const u8) !bool {
            return glfw.extensionSupported(extension_name);
        }
    }{});

    const vertex_shader_source =
        \\#version 330
        \\
        \\uniform mat4 matrix;
        \\
        \\in vec4 position;
        \\in vec4 normal;
        \\in vec4 color;
        \\
        \\out vec4 v_Color;
        \\
        \\void main() {
        \\  gl_Position = matrix * position;
        \\
        \\  v_Color = color;
        \\}
    ;
    const fragment_shader_source =
        \\#version 330
        \\
        \\in vec4 v_Color;
        \\
        \\out vec4 f_Color;
        \\
        \\void main() {
        \\  f_Color = v_Color;
        \\}
    ;
    const program = gl.createProgram();
    defer gl.deleteProgram(program);
    {
        var success: gl.Int = undefined;
        var info_log: [256:0]u8 = undefined;

        const vertex_shader = gl.createShader(gl.VERTEX_SHADER);
        defer gl.deleteShader(vertex_shader);
        gl.shaderSource(vertex_shader, 1, &@as([*:0]const u8, vertex_shader_source), null);
        gl.compileShader(vertex_shader);
        gl.getShaderiv(vertex_shader, gl.COMPILE_STATUS, &success);
        if (success == 0) {
            gl.getShaderInfoLog(vertex_shader, info_log.len, null, &info_log);
            std.log.err("gl: {s}", .{@as([*:0]const u8, &info_log)});
            return error.InitFailed;
        }
        gl.attachShader(program, vertex_shader);

        const fragment_shader = gl.createShader(gl.FRAGMENT_SHADER);
        defer gl.deleteShader(fragment_shader);
        gl.shaderSource(fragment_shader, 1, &@as([*:0]const u8, fragment_shader_source), null);
        gl.compileShader(fragment_shader);
        gl.getShaderiv(fragment_shader, gl.COMPILE_STATUS, &success);
        if (success == 0) {
            gl.getShaderInfoLog(fragment_shader, info_log.len, null, &info_log);
            std.log.err("gl: {s}", .{@as([*:0]const u8, &info_log)});
            return error.InitFailed;
        }
        gl.attachShader(program, fragment_shader);

        gl.linkProgram(program);
        gl.getProgramiv(program, gl.LINK_STATUS, &success);
        if (success == 0) {
            gl.getProgramInfoLog(program, info_log.len, null, &info_log);
            std.log.err("gl: {s}", .{@as([*:0]const u8, &info_log)});
            return error.InitFailed;
        }
    }

    const locations = .{
        .matrix = gl.getUniformLocation(program, "matrix"),
        .position = gl.getAttribLocation(program, "position"),
        .normal = gl.getAttribLocation(program, "normal"),
        .color = gl.getAttribLocation(program, "color"),
    };

    var vertex_buffer: gl.Uint = undefined;
    gl.genBuffers(1, &vertex_buffer);
    defer gl.deleteBuffers(1, &vertex_buffer);

    var vao: gl.Uint = undefined;
    gl.genVertexArrays(1, &vao);
    defer gl.deleteVertexArrays(1, &vao);
    {
        gl.bindVertexArray(vao);
        defer gl.bindVertexArray(0);

        gl.bindBuffer(gl.ARRAY_BUFFER, vertex_buffer);
        defer gl.bindBuffer(gl.ARRAY_BUFFER, 0);

        if (locations.position >= 0) {
            const loc = @intCast(gl.Uint, locations.position);
            gl.enableVertexAttribArray(loc);
            gl.vertexAttribPointer(
                loc,
                @typeInfo(std.meta.FieldType(model.Vertex, .position)).Vector.len,
                gl.FLOAT,
                gl.FALSE,
                @sizeOf(model.Vertex),
                @intToPtr(?*anyopaque, @offsetOf(model.Vertex, "position")),
            );
        }
        if (locations.normal >= 0) {
            const loc = @intCast(gl.Uint, locations.normal);
            gl.enableVertexAttribArray(loc);
            gl.vertexAttribPointer(
                loc,
                @typeInfo(std.meta.FieldType(model.Vertex, .normal)).Vector.len,
                gl.FLOAT,
                gl.FALSE,
                @sizeOf(model.Vertex),
                @intToPtr(?*anyopaque, @offsetOf(model.Vertex, "normal")),
            );
        }
        if (locations.color >= 0) {
            const loc = @intCast(gl.Uint, locations.color);
            gl.enableVertexAttribArray(loc);
            gl.vertexAttribPointer(
                loc,
                @typeInfo(std.meta.FieldType(model.Vertex, .color)).Vector.len,
                gl.FLOAT,
                gl.FALSE,
                @sizeOf(model.Vertex),
                @intToPtr(?*anyopaque, @offsetOf(model.Vertex, "color")),
            );
        }

        gl.bufferData(gl.ARRAY_BUFFER, @sizeOf(@TypeOf(model.mesh)), &model.mesh, gl.STATIC_DRAW);
    }

    const object_matrix = zmath.translation(-model.origin[0], -model.origin[1], -model.origin[2]);

    const world_matrices = [_]zmath.Mat{
        zmath.translation(-5, 0, 5),
        zmath.translation(5, 0, 5),
        zmath.translation(0, 0, 0),
        zmath.translation(-5, 0, -5),
        zmath.translation(5, 0, -5),
    };

    const projection_matrix = zmath.perspectiveFovLhGl(
        std.math.pi / 4.0,
        @intToFloat(f32, window_width) / @intToFloat(f32, window_height),
        0.25,
        256,
    );

    var camera_yaw: f32 = 0;
    var camera_pitch: f32 = 0;

    var time: gl.Sizei = 0;

    while (!window.shouldClose()) {
        gl.clearColor(0.25, 0.25, 0.25, 1);
        gl.clear(gl.DEPTH_BUFFER_BIT | gl.COLOR_BUFFER_BIT);

        {
            gl.useProgram(program);
            defer gl.useProgram(0);
            gl.bindVertexArray(vao);
            defer gl.bindVertexArray(0);

            gl.enable(gl.DEPTH_TEST);
            defer gl.disable(gl.DEPTH_TEST);
            gl.enable(gl.CULL_FACE);
            defer gl.disable(gl.CULL_FACE);

            const rotation_amount = 1.0 / 256.0;

            if (keyboard.current.contains(.left)) {
                camera_yaw = @rem(camera_yaw + rotation_amount, 2.0);
            }
            if (keyboard.current.contains(.right)) {
                camera_yaw = @rem(camera_yaw - rotation_amount, 2.0);
            }
            if (keyboard.current.contains(.down)) {
                camera_pitch = @max(@min(camera_pitch - rotation_amount, 0.5), -0.5);
            }
            if (keyboard.current.contains(.up)) {
                camera_pitch = @max(@min(camera_pitch + rotation_amount, 0.5), -0.5);
            }

            if (keyboard.current.contains(.d) and !keyboard.previous.contains(.d)) {
                std.debug.print("camera: yaw: {d:.5}, pitch: {d:.5}\n", .{ camera_yaw, camera_pitch });
            }
            if (keyboard.current.contains(.r) and !keyboard.previous.contains(.r)) {
                camera_yaw = 0;
                camera_pitch = 0;
                time = 0;
            }

            const view_matrix = blk: {
                var mat = zmath.translation(0, 0, -20);
                mat = zmath.mul(mat, zmath.rotationX(camera_pitch * std.math.pi));
                mat = zmath.mul(mat, zmath.rotationY(camera_yaw * std.math.pi));
                mat = zmath.inverse(mat);
                break :blk mat;
            };

            for (world_matrices) |world_matrix| {
                const owvp = blk: {
                    var mat = object_matrix;
                    mat = zmath.mul(mat, world_matrix);
                    mat = zmath.mul(mat, view_matrix);
                    mat = zmath.mul(mat, projection_matrix);
                    break :blk mat;
                };

                gl.uniformMatrix4fv(locations.matrix, 1, gl.FALSE, &@bitCast([16]gl.Float, owvp));
                gl.drawArrays(gl.TRIANGLES, 0, @min(@divTrunc(time, 3), @as(gl.Sizei, model.mesh.len)));
            }
        }

        window.swapBuffers();
        keyboard.previous = keyboard.current;
        time +|= 1;
        glfw.pollEvents();
    }
}
