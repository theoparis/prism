//! Prism's EGL frontend (libEGL_prism.so), a libglvnd EGL vendor. Registered via
//! share/glvnd/egl_vendor.d/50_prism.json. Also exports EGL 1.5 entry points for
//! direct dlopen validation when no GLVND loader is available.

const std = @import("std");
const prism = @import("prism");

pub const egl = @import("prism-egl/egl.zig");
pub const state = @import("prism-egl/state.zig");
pub const vendor = @import("prism-egl/vendor.zig");
pub const gles = @import("prism-egl/gles.zig");
pub const wl_egl_window = @import("prism-egl/wl_egl_window.zig");

// GLVND EGL vendor entry point

/// EGLBoolean __egl_Main(uint32_t version, const __EGLapiExports *exports,
///         __EGLvendorInfo *vendor, __EGLapiImports *imports);
export fn __egl_Main(
    version: u32,
    exports: ?*const egl.EGLapiExports,
    vendor_info: ?*egl.EGLvendorInfo,
    imports: ?*egl.EGLapiImports,
) callconv(.c) egl.EGLBoolean {
    return vendor.eglMain(version, exports, vendor_info, imports);
}

// EGL 1.5 core entry points (direct-dlopen validation path)

export fn eglGetError() callconv(.c) egl.EGLint {
    return vendor.eglGetError();
}
export fn eglGetDisplay(native_display: ?*anyopaque) callconv(.c) egl.EGLDisplay {
    return vendor.eglGetDisplay(native_display);
}
export fn eglGetPlatformDisplay(
    platform: egl.EGLenum,
    native_display: ?*anyopaque,
    attrib_list: ?[*]const egl.EGLAttrib,
) callconv(.c) egl.EGLDisplay {
    return vendor.eglGetPlatformDisplay(platform, native_display, attrib_list);
}
export fn eglGetPlatformDisplayEXT(
    platform: egl.EGLenum,
    native_display: ?*anyopaque,
    attrib_list: ?[*]const egl.EGLint,
) callconv(.c) egl.EGLDisplay {
    return vendor.eglGetPlatformDisplayEXT(platform, native_display, attrib_list);
}
export fn eglInitialize(dpy: egl.EGLDisplay, major: ?*egl.EGLint, minor: ?*egl.EGLint) callconv(.c) egl.EGLBoolean {
    return vendor.eglInitialize(dpy, major, minor);
}
export fn eglTerminate(dpy: egl.EGLDisplay) callconv(.c) egl.EGLBoolean {
    return vendor.eglTerminate(dpy);
}
export fn eglQueryString(dpy: egl.EGLDisplay, name: egl.EGLint) callconv(.c) ?[*:0]const u8 {
    return vendor.eglQueryString(dpy, name);
}
export fn eglGetConfigs(
    dpy: egl.EGLDisplay,
    configs: ?[*]egl.EGLConfig,
    config_size: egl.EGLint,
    num_config: ?*egl.EGLint,
) callconv(.c) egl.EGLBoolean {
    return vendor.eglGetConfigs(dpy, configs, config_size, num_config);
}
export fn eglChooseConfig(
    dpy: egl.EGLDisplay,
    attrib_list: ?[*]const egl.EGLint,
    configs: ?[*]egl.EGLConfig,
    config_size: egl.EGLint,
    num_config: ?*egl.EGLint,
) callconv(.c) egl.EGLBoolean {
    return vendor.eglChooseConfig(dpy, attrib_list, configs, config_size, num_config);
}
export fn eglGetConfigAttrib(
    dpy: egl.EGLDisplay,
    config: egl.EGLConfig,
    attribute: egl.EGLint,
    value: ?*egl.EGLint,
) callconv(.c) egl.EGLBoolean {
    return vendor.eglGetConfigAttrib(dpy, config, attribute, value);
}
export fn eglBindAPI(api: egl.EGLenum) callconv(.c) egl.EGLBoolean {
    return vendor.eglBindAPI(api);
}
export fn eglQueryAPI() callconv(.c) egl.EGLenum {
    return vendor.eglQueryAPI();
}
export fn eglReleaseThread() callconv(.c) egl.EGLBoolean {
    return vendor.eglReleaseThread();
}
export fn eglGetProcAddress(procname: ?[*:0]const u8) callconv(.c) egl.ProcFn {
    return vendor.eglGetProcAddress(procname);
}

// M2 surface/context stubs (exported so direct-dlopen apps can resolve them).
export fn eglCreateContext(
    dpy: egl.EGLDisplay,
    config: egl.EGLConfig,
    share: egl.EGLContext,
    attrib_list: ?[*]const egl.EGLint,
) callconv(.c) egl.EGLContext {
    return vendor.eglCreateContext(dpy, config, share, attrib_list);
}
export fn eglDestroyContext(dpy: egl.EGLDisplay, ctx: egl.EGLContext) callconv(.c) egl.EGLBoolean {
    return vendor.eglDestroyContext(dpy, ctx);
}
export fn eglCreateWindowSurface(
    dpy: egl.EGLDisplay,
    config: egl.EGLConfig,
    win: ?*anyopaque,
    attrib_list: ?[*]const egl.EGLint,
) callconv(.c) egl.EGLSurface {
    return vendor.eglCreateWindowSurface(dpy, config, win, attrib_list);
}
export fn eglCreatePbufferSurface(
    dpy: egl.EGLDisplay,
    config: egl.EGLConfig,
    attrib_list: ?[*]const egl.EGLint,
) callconv(.c) egl.EGLSurface {
    return vendor.eglCreatePbufferSurface(dpy, config, attrib_list);
}
export fn eglDestroySurface(dpy: egl.EGLDisplay, surface: egl.EGLSurface) callconv(.c) egl.EGLBoolean {
    return vendor.eglDestroySurface(dpy, surface);
}
export fn eglMakeCurrent(
    dpy: egl.EGLDisplay,
    draw: egl.EGLSurface,
    read: egl.EGLSurface,
    ctx: egl.EGLContext,
) callconv(.c) egl.EGLBoolean {
    return vendor.eglMakeCurrent(dpy, draw, read, ctx);
}
export fn eglCreatePlatformWindowSurface(
    dpy: egl.EGLDisplay,
    config: egl.EGLConfig,
    native_window: ?*anyopaque,
    attrib_list: ?[*]const egl.EGLAttrib,
) callconv(.c) egl.EGLSurface {
    return vendor.eglCreatePlatformWindowSurface(dpy, config, native_window, attrib_list);
}
export fn eglCreatePlatformWindowSurfaceEXT(
    dpy: egl.EGLDisplay,
    config: egl.EGLConfig,
    native_window: ?*anyopaque,
    attrib_list: ?[*]const egl.EGLint,
) callconv(.c) egl.EGLSurface {
    _ = attrib_list;
    return vendor.eglCreatePlatformWindowSurface(dpy, config, native_window, null);
}
export fn eglSwapBuffers(dpy: egl.EGLDisplay, surface: egl.EGLSurface) callconv(.c) egl.EGLBoolean {
    return vendor.eglSwapBuffers(dpy, surface);
}
export fn eglGetCurrentContext() callconv(.c) egl.EGLContext {
    return vendor.eglGetCurrentContext();
}
export fn eglGetCurrentDisplay() callconv(.c) egl.EGLDisplay {
    return vendor.eglGetCurrentDisplay();
}
export fn eglGetCurrentSurface(readdraw: egl.EGLint) callconv(.c) egl.EGLSurface {
    return vendor.eglGetCurrentSurface(readdraw);
}
export fn eglQuerySurface(dpy: egl.EGLDisplay, surface: egl.EGLSurface, attribute: egl.EGLint, value: ?*egl.EGLint) callconv(.c) egl.EGLBoolean {
    return vendor.eglQuerySurface(dpy, surface, attribute, value);
}
export fn eglQueryContext(dpy: egl.EGLDisplay, ctx: egl.EGLContext, attribute: egl.EGLint, value: ?*egl.EGLint) callconv(.c) egl.EGLBoolean {
    return vendor.eglQueryContext(dpy, ctx, attribute, value);
}

// Minimal GLES entry points (direct-dlsym render path)
export fn glClearColor(r: gles.GLclampf, g: gles.GLclampf, b: gles.GLclampf, a: gles.GLclampf) callconv(.c) void {
    return vendor.glClearColor(r, g, b, a);
}
export fn glClear(mask: gles.GLbitfield) callconv(.c) void {
    return vendor.glClear(mask);
}
export fn glViewport(x: gles.GLint, y: gles.GLint, width: gles.GLsizei, height: gles.GLsizei) callconv(.c) void {
    return vendor.glViewport(x, y, width, height);
}
export fn glGetString(name: gles.GLenum) callconv(.c) ?[*:0]const gles.GLubyte {
    return vendor.glGetString(name);
}
export fn glGetError() callconv(.c) gles.GLenum {
    return vendor.glGetError();
}
export fn glFinish() callconv(.c) void {
    return vendor.glFinish();
}
export fn glFlush() callconv(.c) void {
    return vendor.glFlush();
}

// GLES2 triangle path (shaders + programs + buffers + attribs + draw)
export fn glGenBuffersARB(n: gles.GLsizei, buffers: ?[*]gles.GLuint) callconv(.c) void {
    return vendor.glGenBuffersARB(n, buffers);
}
export fn glGenBuffers(n: gles.GLsizei, buffers: ?[*]gles.GLuint) callconv(.c) void {
    return vendor.glGenBuffers(n, buffers);
}
export fn glBindBuffer(target: gles.GLenum, buffer: gles.GLuint) callconv(.c) void {
    return vendor.glBindBuffer(target, buffer);
}
export fn glBufferData(target: gles.GLenum, size: gles.GLsizeiptr, data: ?*const anyopaque, usage: gles.GLenum) callconv(.c) void {
    return vendor.glBufferData(target, size, data, usage);
}
export fn glDeleteBuffers(n: gles.GLsizei, buffers: ?[*]const gles.GLuint) callconv(.c) void {
    return vendor.glDeleteBuffers(n, buffers);
}
export fn glVertexAttribPointer(index: gles.GLuint, size: gles.GLint, gl_type: gles.GLenum, normalized: gles.GLboolean, stride: gles.GLsizei, pointer: ?*const anyopaque) callconv(.c) void {
    return vendor.glVertexAttribPointer(index, size, gl_type, normalized, stride, pointer);
}
export fn glEnableVertexAttribArray(index: gles.GLuint) callconv(.c) void {
    return vendor.glEnableVertexAttribArray(index);
}
export fn glDisableVertexAttribArray(index: gles.GLuint) callconv(.c) void {
    return vendor.glDisableVertexAttribArray(index);
}
export fn glCreateShader(shader_type: gles.GLenum) callconv(.c) gles.GLuint {
    return vendor.glCreateShader(shader_type);
}
export fn glShaderSource(shader: gles.GLuint, count: gles.GLsizei, string: ?[*]const ?[*:0]const gles.GLchar, length: ?[*]const gles.GLint) callconv(.c) void {
    return vendor.glShaderSource(shader, count, string, length);
}
export fn glShaderBinary(count: gles.GLsizei, shaders: ?[*]const gles.GLuint, binaryformat: gles.GLenum, binary: ?*const anyopaque, length: gles.GLsizei) callconv(.c) void {
    return vendor.glShaderBinary(count, shaders, binaryformat, binary, length);
}
export fn glCompileShader(shader: gles.GLuint) callconv(.c) void {
    return vendor.glCompileShader(shader);
}
export fn glSpecializeShader(shader: gles.GLuint, entry: ?[*:0]const gles.GLchar, num: gles.GLuint, idx: ?[*]const gles.GLuint, val: ?[*]const gles.GLuint) callconv(.c) void {
    return vendor.glSpecializeShader(shader, entry, num, idx, val);
}
export fn glGetShaderiv(shader: gles.GLuint, pname: gles.GLenum, params: ?*gles.GLint) callconv(.c) void {
    return vendor.glGetShaderiv(shader, pname, params);
}
export fn glGetShaderInfoLog(shader: gles.GLuint, buf_size: gles.GLsizei, length: ?*gles.GLint, info_log: ?[*]gles.GLchar) callconv(.c) void {
    return vendor.glGetShaderInfoLog(shader, buf_size, length, info_log);
}
export fn glDeleteShader(shader: gles.GLuint) callconv(.c) void {
    return vendor.glDeleteShader(shader);
}
export fn glCreateProgram() callconv(.c) gles.GLuint {
    return vendor.glCreateProgram();
}
export fn glAttachShader(program: gles.GLuint, shader: gles.GLuint) callconv(.c) void {
    return vendor.glAttachShader(program, shader);
}
export fn glDetachShader(program: gles.GLuint, shader: gles.GLuint) callconv(.c) void {
    return vendor.glDetachShader(program, shader);
}
export fn glLinkProgram(program: gles.GLuint) callconv(.c) void {
    return vendor.glLinkProgram(program);
}
export fn glUseProgram(program: gles.GLuint) callconv(.c) void {
    return vendor.glUseProgram(program);
}
export fn glGetProgramiv(program: gles.GLuint, pname: gles.GLenum, params: ?*gles.GLint) callconv(.c) void {
    return vendor.glGetProgramiv(program, pname, params);
}
export fn glDeleteProgram(program: gles.GLuint) callconv(.c) void {
    return vendor.glDeleteProgram(program);
}
export fn glGetAttribLocation(program: gles.GLuint, name: ?[*:0]const gles.GLchar) callconv(.c) gles.GLint {
    return vendor.glGetAttribLocation(program, name);
}
export fn glDrawArrays(mode: gles.GLenum, first: gles.GLint, count: gles.GLsizei) callconv(.c) void {
    return vendor.glDrawArrays(mode, first, count);
}
export fn glDrawElements(mode: gles.GLenum, count: gles.GLsizei, index_type: gles.GLenum, indices: ?*const anyopaque) callconv(.c) void {
    return vendor.glDrawElements(mode, count, index_type, indices);
}
export fn glBindAttribLocation(program: gles.GLuint, index: gles.GLuint, name: ?[*:0]const gles.GLchar) callconv(.c) void {
    return vendor.glBindAttribLocation(program, index, name);
}
export fn glGetUniformLocation(program: gles.GLuint, name: ?[*:0]const gles.GLchar) callconv(.c) gles.GLint {
    return vendor.glGetUniformLocation(program, name);
}
export fn glGetProgramInfoLog(program: gles.GLuint, buf_size: gles.GLsizei, length: ?*gles.GLint, info_log: ?[*]gles.GLchar) callconv(.c) void {
    return vendor.glGetProgramInfoLog(program, buf_size, length, info_log);
}
export fn glUniform1f(location: gles.GLint, v0: gles.GLfloat) callconv(.c) void {
    return vendor.glUniform1f(location, v0);
}
export fn glUniform2f(location: gles.GLint, v0: gles.GLfloat, v1: gles.GLfloat) callconv(.c) void {
    return vendor.glUniform2f(location, v0, v1);
}
export fn glUniform3f(location: gles.GLint, v0: gles.GLfloat, v1: gles.GLfloat, v2: gles.GLfloat) callconv(.c) void {
    return vendor.glUniform3f(location, v0, v1, v2);
}
export fn glUniform4f(location: gles.GLint, v0: gles.GLfloat, v1: gles.GLfloat, v2: gles.GLfloat, v3: gles.GLfloat) callconv(.c) void {
    return vendor.glUniform4f(location, v0, v1, v2, v3);
}
export fn glUniform1i(location: gles.GLint, v0: gles.GLint) callconv(.c) void {
    return vendor.glUniform1i(location, v0);
}
export fn glUniform1fv(location: gles.GLint, count: gles.GLsizei, value: ?[*]const gles.GLfloat) callconv(.c) void {
    return vendor.glUniform1fv(location, count, value);
}
export fn glUniform2fv(location: gles.GLint, count: gles.GLsizei, value: ?[*]const gles.GLfloat) callconv(.c) void {
    return vendor.glUniform2fv(location, count, value);
}
export fn glUniform3fv(location: gles.GLint, count: gles.GLsizei, value: ?[*]const gles.GLfloat) callconv(.c) void {
    return vendor.glUniform3fv(location, count, value);
}
export fn glUniform4fv(location: gles.GLint, count: gles.GLsizei, value: ?[*]const gles.GLfloat) callconv(.c) void {
    return vendor.glUniform4fv(location, count, value);
}
export fn glUniformMatrix2fv(location: gles.GLint, count: gles.GLsizei, transpose: gles.GLboolean, value: ?[*]const gles.GLfloat) callconv(.c) void {
    return vendor.glUniformMatrix2fv(location, count, transpose, value);
}
export fn glUniformMatrix3fv(location: gles.GLint, count: gles.GLsizei, transpose: gles.GLboolean, value: ?[*]const gles.GLfloat) callconv(.c) void {
    return vendor.glUniformMatrix3fv(location, count, transpose, value);
}
export fn glUniformMatrix4fv(location: gles.GLint, count: gles.GLsizei, transpose: gles.GLboolean, value: ?[*]const gles.GLfloat) callconv(.c) void {
    return vendor.glUniformMatrix4fv(location, count, transpose, value);
}
export fn glEnable(cap: gles.GLenum) callconv(.c) void {
    return vendor.glEnable(cap);
}
export fn glDisable(cap: gles.GLenum) callconv(.c) void {
    return vendor.glDisable(cap);
}
export fn glDepthFunc(func: gles.GLenum) callconv(.c) void {
    return vendor.glDepthFunc(func);
}
export fn glDepthMask(flag: gles.GLboolean) callconv(.c) void {
    return vendor.glDepthMask(flag);
}
export fn glClearDepthf(d: gles.GLclampf) callconv(.c) void {
    return vendor.glClearDepthf(d);
}
export fn glCullFace(mode: gles.GLenum) callconv(.c) void {
    return vendor.glCullFace(mode);
}
export fn glFrontFace(mode: gles.GLenum) callconv(.c) void {
    return vendor.glFrontFace(mode);
}

// GLES2 textures / samplers (direct-dlsym path)
export fn glGenTextures(n: gles.GLsizei, txs: ?[*]gles.GLuint) callconv(.c) void {
    return vendor.glGenTextures(n, txs);
}
export fn glDeleteTextures(n: gles.GLsizei, txs: ?[*]const gles.GLuint) callconv(.c) void {
    return vendor.glDeleteTextures(n, txs);
}
export fn glBindTexture(target: gles.GLenum, texture: gles.GLuint) callconv(.c) void {
    return vendor.glBindTexture(target, texture);
}
export fn glActiveTexture(texture: gles.GLenum) callconv(.c) void {
    return vendor.glActiveTexture(texture);
}
export fn glIsTexture(texture: gles.GLuint) callconv(.c) gles.GLboolean {
    return vendor.glIsTexture(texture);
}
export fn glTexParameteri(target: gles.GLenum, pname: gles.GLenum, param: gles.GLint) callconv(.c) void {
    return vendor.glTexParameteri(target, pname, param);
}
export fn glTexParameterf(target: gles.GLenum, pname: gles.GLenum, param: gles.GLfloat) callconv(.c) void {
    return vendor.glTexParameterf(target, pname, param);
}
export fn glTexImage2D(target: gles.GLenum, level: gles.GLint, internalformat: gles.GLint, width: gles.GLsizei, height: gles.GLsizei, border: gles.GLint, format: gles.GLenum, gl_type: gles.GLenum, pixels: ?*const anyopaque) callconv(.c) void {
    return vendor.glTexImage2D(target, level, internalformat, width, height, border, format, gl_type, pixels);
}
export fn glTexSubImage2D(target: gles.GLenum, level: gles.GLint, xoffset: gles.GLint, yoffset: gles.GLint, width: gles.GLsizei, height: gles.GLsizei, format: gles.GLenum, gl_type: gles.GLenum, pixels: ?*const anyopaque) callconv(.c) void {
    return vendor.glTexSubImage2D(target, level, xoffset, yoffset, width, height, format, gl_type, pixels);
}
export fn glPixelStorei(pname: gles.GLenum, param: gles.GLint) callconv(.c) void {
    return vendor.glPixelStorei(pname, param);
}
export fn glGenerateMipmap(target: gles.GLenum) callconv(.c) void {
    return vendor.glGenerateMipmap(target);
}

// GLES2 state setters previously reachable only via eglGetProcAddress; exported so a
// direct-linking consumer (LCE) resolves them at link time.
export fn glLineWidth(w: gles.GLfloat) callconv(.c) void {
    return vendor.glLineWidth(w);
}
export fn glGetFloatv(pname: gles.GLenum, params: ?[*]gles.GLfloat) callconv(.c) void {
    return vendor.glGetFloatv(pname, params);
}
export fn glPolygonOffset(factor: gles.GLfloat, units: gles.GLfloat) callconv(.c) void {
    return vendor.glPolygonOffset(factor, units);
}
export fn glStencilFunc(func: gles.GLenum, ref: gles.GLint, mask: gles.GLuint) callconv(.c) void {
    return vendor.glStencilFunc(func, ref, mask);
}
export fn glStencilOp(sfail: gles.GLenum, dpfail: gles.GLenum, dppass: gles.GLenum) callconv(.c) void {
    return vendor.glStencilOp(sfail, dpfail, dppass);
}
export fn glStencilMask(mask: gles.GLuint) callconv(.c) void {
    return vendor.glStencilMask(mask);
}
export fn glBlendFunc(sfactor: gles.GLenum, dfactor: gles.GLenum) callconv(.c) void {
    return vendor.glBlendFunc(sfactor, dfactor);
}
export fn glColorMask(r: gles.GLboolean, g: gles.GLboolean, b: gles.GLboolean, a: gles.GLboolean) callconv(.c) void {
    return vendor.glColorMask(r, g, b, a);
}
export fn glReadPixels(x: gles.GLint, y: gles.GLint, width: gles.GLsizei, height: gles.GLsizei, format: gles.GLenum, gl_type: gles.GLenum, pixels: ?*anyopaque) callconv(.c) void {
    return vendor.glReadPixels(x, y, width, height, format, gl_type, pixels);
}

// Legacy GL1.x / GLES1 fixed-function pipeline (direct-dlsym path).
export fn glMatrixMode(mode: gles.GLenum) callconv(.c) void {
    return vendor.glMatrixMode(mode);
}
export fn glLoadIdentity() callconv(.c) void {
    return vendor.glLoadIdentity();
}
export fn glLoadMatrixf(m: ?[*]const gles.GLfloat) callconv(.c) void {
    return vendor.glLoadMatrixf(m);
}
export fn glMultMatrixf(m: ?[*]const gles.GLfloat) callconv(.c) void {
    return vendor.glMultMatrixf(m);
}
export fn glPushMatrix() callconv(.c) void {
    return vendor.glPushMatrix();
}
export fn glPopMatrix() callconv(.c) void {
    return vendor.glPopMatrix();
}
export fn glTranslatef(x: gles.GLfloat, y: gles.GLfloat, z: gles.GLfloat) callconv(.c) void {
    return vendor.glTranslatef(x, y, z);
}
export fn glScalef(x: gles.GLfloat, y: gles.GLfloat, z: gles.GLfloat) callconv(.c) void {
    return vendor.glScalef(x, y, z);
}
export fn glRotatef(angle: gles.GLfloat, x: gles.GLfloat, y: gles.GLfloat, z: gles.GLfloat) callconv(.c) void {
    return vendor.glRotatef(angle, x, y, z);
}
export fn glOrtho(l: gles.GLdouble, r: gles.GLdouble, b: gles.GLdouble, t: gles.GLdouble, n: gles.GLdouble, f: gles.GLdouble) callconv(.c) void {
    return vendor.glOrtho(l, r, b, t, n, f);
}
export fn glOrthof(l: gles.GLfloat, r: gles.GLfloat, b: gles.GLfloat, t: gles.GLfloat, n: gles.GLfloat, f: gles.GLfloat) callconv(.c) void {
    return vendor.glOrthof(l, r, b, t, n, f);
}
export fn glFrustum(l: gles.GLdouble, r: gles.GLdouble, b: gles.GLdouble, t: gles.GLdouble, n: gles.GLdouble, f: gles.GLdouble) callconv(.c) void {
    return vendor.glFrustum(l, r, b, t, n, f);
}
export fn glFrustumf(l: gles.GLfloat, r: gles.GLfloat, b: gles.GLfloat, t: gles.GLfloat, n: gles.GLfloat, f: gles.GLfloat) callconv(.c) void {
    return vendor.glFrustumf(l, r, b, t, n, f);
}
export fn glColor4f(r: gles.GLfloat, g: gles.GLfloat, b: gles.GLfloat, a: gles.GLfloat) callconv(.c) void {
    return vendor.glColor4f(r, g, b, a);
}
export fn glColor3f(r: gles.GLfloat, g: gles.GLfloat, b: gles.GLfloat) callconv(.c) void {
    return vendor.glColor3f(r, g, b);
}
export fn glNormal3f(x: gles.GLfloat, y: gles.GLfloat, z: gles.GLfloat) callconv(.c) void {
    return vendor.glNormal3f(x, y, z);
}
export fn glShadeModel(mode: gles.GLenum) callconv(.c) void {
    return vendor.glShadeModel(mode);
}
export fn glAlphaFunc(func: gles.GLenum, ref: gles.GLfloat) callconv(.c) void {
    return vendor.glAlphaFunc(func, ref);
}
export fn glFogf(pname: gles.GLenum, param: gles.GLfloat) callconv(.c) void {
    return vendor.glFogf(pname, param);
}
export fn glFogfv(pname: gles.GLenum, params: ?[*]const gles.GLfloat) callconv(.c) void {
    return vendor.glFogfv(pname, params);
}
export fn glLightfv(light: gles.GLenum, pname: gles.GLenum, params: ?[*]const gles.GLfloat) callconv(.c) void {
    return vendor.glLightfv(light, pname, params);
}
export fn glLightModelfv(pname: gles.GLenum, params: ?[*]const gles.GLfloat) callconv(.c) void {
    return vendor.glLightModelfv(pname, params);
}
export fn glMaterialfv(face: gles.GLenum, pname: gles.GLenum, params: ?[*]const gles.GLfloat) callconv(.c) void {
    return vendor.glMaterialfv(face, pname, params);
}
export fn glTexGeni(coord: gles.GLenum, pname: gles.GLenum, param: gles.GLint) callconv(.c) void {
    return vendor.glTexGeni(coord, pname, param);
}
export fn glMultiTexCoord4f(target: gles.GLenum, s: gles.GLfloat, t: gles.GLfloat, r: gles.GLfloat, q: gles.GLfloat) callconv(.c) void {
    return vendor.glMultiTexCoord4f(target, s, t, r, q);
}
export fn glEnableClientState(cap: gles.GLenum) callconv(.c) void {
    return vendor.glEnableClientState(cap);
}
export fn glDisableClientState(cap: gles.GLenum) callconv(.c) void {
    return vendor.glDisableClientState(cap);
}
export fn glVertexPointer(size: gles.GLint, gl_type: gles.GLenum, stride: gles.GLsizei, pointer: ?*const anyopaque) callconv(.c) void {
    return vendor.glVertexPointer(size, gl_type, stride, pointer);
}
export fn glColorPointer(size: gles.GLint, gl_type: gles.GLenum, stride: gles.GLsizei, pointer: ?*const anyopaque) callconv(.c) void {
    return vendor.glColorPointer(size, gl_type, stride, pointer);
}
export fn glTexCoordPointer(size: gles.GLint, gl_type: gles.GLenum, stride: gles.GLsizei, pointer: ?*const anyopaque) callconv(.c) void {
    return vendor.glTexCoordPointer(size, gl_type, stride, pointer);
}
export fn glGenLists(range: gles.GLsizei) callconv(.c) gles.GLuint {
    return vendor.glGenLists(range);
}
export fn glNewList(list: gles.GLuint, mode: gles.GLenum) callconv(.c) void {
    return vendor.glNewList(list, mode);
}
export fn glEndList() callconv(.c) void {
    return vendor.glEndList();
}
export fn glCallList(list: gles.GLuint) callconv(.c) void {
    return vendor.glCallList(list);
}
export fn glDeleteLists(list: gles.GLuint, range: gles.GLsizei) callconv(.c) void {
    return vendor.glDeleteLists(list, range);
}

test "core reachable from egl frontend" {
    try std.testing.expect(prism.version.len > 0);
}

test "__egl_Main export has the GLVND signature and succeeds" {
    var imports: egl.EGLapiImports = undefined;
    const ok = __egl_Main((egl.EGL_VENDOR_ABI_MAJOR_VERSION << 16) | 2, null, null, &imports);
    try std.testing.expectEqual(egl.EGL_TRUE, ok);
    try std.testing.expect(imports.getPlatformDisplay != null);
}

test {
    _ = egl;
    _ = state;
    _ = vendor;
    _ = gles;
}
