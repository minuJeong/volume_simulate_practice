from watchdog.observers import Observer
from watchdog.events import FileSystemEventHandler

import glfw
import numpy as np
import moderngl as mg


class GLState(object):
    def __init__(self):
        super(GLState, self).__init__()

    def start(self):
        if not glfw.init():
            return

        glfw.window_hint(glfw.FLOATING, True)
        self.u_width, self.u_height = 512, 512
        self.window = glfw.create_window(
            self.u_width, self.u_height, "pyGLFW window", None, None
        )
        if not self.window:
            glfw.terminate()
            return

        glfw.make_context_current(self.window)

        self.init()
        self.should_rebuild = False

        handler = FileSystemEventHandler()
        handler.on_modified = lambda e: self.set_rebuild(True)
        observer = Observer()
        observer.schedule(handler, "./gl")
        observer.start()

    def mainloop(self):
        while not glfw.window_should_close(self.window):
            if self.should_rebuild:
                self.rebuild_vao()
                self.should_rebuild = False

            self.update_uniforms({"u_time": glfw.get_time()})
            # self.update_uniforms({"u_time": time.time() % 1000.0})
            self.render()

            glfw.swap_buffers(self.window)
            glfw.poll_events()

        glfw.terminate()

    def read(self, path):
        with open(path, "r") as fp:
            return fp.read()

    def set_rebuild(self, should_rebuild):
        self.should_rebuild = should_rebuild

    def rebuild_vao(self):
        try:
            self.cs_volume = self.gl.compute_shader(self.read("./gl/cs_volume.glsl"))
            self.program = self.gl.program(
                vertex_shader=self.read("./gl/vs.glsl"),
                fragment_shader=self.read("./gl/fs.glsl"),
            )
            self.vao = self.gl.vertex_array(self.program, self.vbo, self.ibo)
            self.volume_buffer.bind_to_storage_buffer(1)
            self.update_uniforms(
                {
                    "u_width": self.u_width,
                    "u_height": self.u_height,
                    "u_volume_size": (self.u_volume_size),
                }
            )
            print("compiled program")

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

        self.u_volume_size = (32, 32, 32)
        w, h, d = self.u_volume_size[0], self.u_volume_size[1], self.u_volume_size[2]
        self.gx, self.gy, self.gz = (int(w / 4), int(h / 4), int(d / 4))
        self.volume_buffer = self.gl.buffer(reserve=w * h * d * 4)

        self.rebuild_vao()

    def update_uniforms(self, uniforms):
        for p in [self.program, self.cs_volume]:
            for n, v in uniforms.items():
                if n in p:
                    p[n].value = v

    def render(self):
        self.cs_volume.run(self.gx, self.gy, self.gz)

        # with self.scope:
        #     self.vao.render()

        # self.tex0.use(0)
        self.vao.render()


def main():
    gl_state = GLState()
    gl_state.start()
    gl_state.mainloop()


if __name__ == "__main__":
    main()
