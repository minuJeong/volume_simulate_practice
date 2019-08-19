import os

from watchdog.observers import Observer
from watchdog.events import FileSystemEventHandler

import glfw
import glm
import numpy as np
import moderngl as mg
import imageio as ii


class GLState(object):
    movement = glm.vec3(0.0, 0.0, 0.0)

    def __init__(self):
        super(GLState, self).__init__()

    def start(self):
        if not glfw.init():
            return

        glfw.window_hint(glfw.FLOATING, glfw.TRUE)
        glfw.window_hint(glfw.RESIZABLE, glfw.TRUE)

        self.u_width, self.u_height = 400, 400
        self.u_volume_size = (64, 64, 64)
        self.window = glfw.create_window(
            self.u_width, self.u_height, "pyGLFW window", None, None
        )
        if not self.window:
            glfw.terminate()
            return

        glfw.make_context_current(self.window)

        self.init()
        self.should_rebuild = False

        glfw.set_framebuffer_size_callback(self.window, self.on_resize_fb)
        glfw.set_key_callback(self.window, self.on_key)

        handler = FileSystemEventHandler()
        handler.on_modified = lambda e: self.set_rebuild(True)
        observer = Observer()
        observer.schedule(handler, "./gl")
        observer.start()

    def on_resize_fb(self, window, w, h):
        self.gl.viewport = (0, 0, w, h)
        self.recompile()
        self.update_uniforms({"u_width": w, "u_height": h})

    def on_key(self, window, key, scancode, action, mods):
        if key == glfw.KEY_SPACE and action == glfw.RELEASE:
            self.serialize_volume("./volume_noise", self.volume_noise_buffer, 1)
            self.serialize_volume("./volume", self.volume_buffer, 4)
            print("Save done!")

    def serialize_volume(self, path, data, color_channels):
        print(f"serializing: {path}..")

        if not os.path.exists(path):
            os.makedirs(path)

        whd = self.u_volume_size
        data = np.frombuffer(data.read(), dtype=np.float32)
        data = np.multiply(data, 255.0)
        data = data.reshape((whd[2], whd[1], whd[0], color_channels)).astype(np.uint8)
        for i, layer in enumerate(data):
            dst = f"{path}/{i}.jpg"
            ii.imwrite(dst, layer[:, :, :3])

    def update(self):
        w = self.window
        LEFT = glfw.get_key(w, glfw.KEY_A) or glfw.get_key(w, glfw.KEY_LEFT)
        FORWARD = glfw.get_key(w, glfw.KEY_W) or glfw.get_key(w, glfw.KEY_UP)
        RIGHT = glfw.get_key(w, glfw.KEY_D) or glfw.get_key(w, glfw.KEY_RIGHT)
        BACK = glfw.get_key(w, glfw.KEY_S) or glfw.get_key(w, glfw.KEY_DOWN)
        UP = glfw.get_key(w, glfw.KEY_E) or glfw.get_key(w, glfw.KEY_PAGE_UP)
        DOWN = glfw.get_key(w, glfw.KEY_Q) or glfw.get_key(w, glfw.KEY_PAGE_DOWN)

        SPEED = 0.1;
        LEFT *= glm.vec3(-1.0, +0.0, +0.0) * SPEED
        FORWARD *= glm.vec3(+0.0, -1.0, +0.0) * SPEED
        RIGHT *= glm.vec3(+1.0, +0.0, +0.0) * SPEED
        BACK *= glm.vec3(+0.0, +1.0, +0.0) * SPEED
        UP *= glm.vec3(+0.0, +0.0, +1.0) * SPEED
        DOWN *= glm.vec3(+0.0, +0.0, -1.0) * SPEED

        self.movement += LEFT + FORWARD + RIGHT + BACK + UP + DOWN
        self.movement.y = glm.max(glm.min(self.movement.y, 50.0), -8.0)
        self.movement.z = glm.max(glm.min(self.movement.z, 30.0), -300.0)
        self.update_uniforms(
            {"u_movement": (self.movement.x, self.movement.y, self.movement.z)}
        )

    def mainloop(self):
        while not glfw.window_should_close(self.window):
            if self.should_rebuild:
                self.recompile()
                self.should_rebuild = False

            self.update_uniforms({"u_time": glfw.get_time()})
            self.render()
            self.update()

            glfw.swap_buffers(self.window)
            glfw.poll_events()

        glfw.terminate()

    def read(self, path):
        with open(path, "r") as fp:
            return fp.read()

    def set_rebuild(self, should_rebuild):
        self.should_rebuild = should_rebuild

    def recompile(self):
        try:
            self.cs_volume_noise = self.gl.compute_shader(
                self.read("./gl/cs_volume_noise.glsl")
            )
            self.cs_volume = self.gl.compute_shader(self.read("./gl/cs_volume.glsl"))
            self.program = self.gl.program(
                vertex_shader=self.read("./gl/vs.glsl"),
                fragment_shader=self.read("./gl/fs.glsl"),
            )
            self.vao = self.gl.vertex_array(self.program, self.vbo, self.ibo)

            self.volume_noise_buffer.bind_to_storage_buffer(0)
            self.volume_buffer.bind_to_storage_buffer(1)
            self.update_uniforms(
                {
                    "u_width": self.u_width,
                    "u_height": self.u_height,
                    "u_volume_size": self.u_volume_size,
                }
            )

            print("compiled program.. refreshing volume noise..")

            self.cs_volume_noise.run(self.gx, self.gy, self.gz)
            print("volume noise refreshed")

        except Exception as e:
            print(e)

    def init(self):
        self.gl = mg.create_context()
        self.vbo = [
            (
                self.gl.buffer(
                    np.array([-1.0, -1.0, -1.0, +1.0, +1.0, -1.0, +1.0, +1.0])
                    .astype(np.float32)
                    .tobytes()
                ),
                "2f",
                "in_pos",
            )
        ]
        self.ibo = self.gl.buffer(
            np.array([0, 1, 2, 2, 1, 3]).astype(np.int32).tobytes()
        )

        self.tex0 = self.gl.texture((self.u_width, self.u_height), 4)
        self.fbo = self.gl.framebuffer([self.tex0])
        self.scope = self.gl.scope(self.fbo)

        w, h, d = self.u_volume_size[0], self.u_volume_size[1], self.u_volume_size[2]
        self.gx, self.gy, self.gz = (int(w / 4), int(h / 4), int(d / 4))

        self.volume_noise_buffer = self.gl.buffer(reserve=w * h * d * 1 * 4)
        self.volume_buffer = self.gl.buffer(reserve=w * h * d * 4 * 4)

        self.recompile()

    def update_uniforms(self, uniforms):
        for p in [self.cs_volume_noise, self.cs_volume, self.program]:
            for n, v in uniforms.items():
                if n in p:
                    p[n].value = v

    def render(self):
        self.cs_volume.run(self.gx, self.gy, self.gz)
        self.vao.render()


def main():
    gl_state = GLState()
    gl_state.start()
    gl_state.mainloop()


if __name__ == "__main__":
    main()
