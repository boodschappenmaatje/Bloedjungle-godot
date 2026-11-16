"""Laat MotionBricks op de CPU draaien: TensorRT -> ONNX Runtime, Warp op 'cpu'."""
import sys, types
from contextlib import contextmanager
from types import MappingProxyType

class _Meta(type):
    def __getattr__(cls, n): return cls
class _Dummy(metaclass=_Meta):
    def __init__(self, *a, **k): pass
    def __getattr__(self, n): return _Dummy()
    def __call__(self, *a, **k): return _Dummy()
trt = types.ModuleType("tensorrt")
trt.__version__ = "10.8.0.43"
trt.__getattr__ = lambda n: _Dummy
sys.modules.setdefault("tensorrt", trt)

import numpy as np
import onnxruntime as ort
import warp as wp
wp.init(); wp.set_device("cpu")

import motionbricks.inference.engine as ie
from motionbricks.inference.types import TensorSpec, TensorMode
import motionbricks.model.engine as me
import motionbricks.model.generation as gen

_ORT2NP = {"tensor(float)": np.float32, "tensor(int32)": np.int32, "tensor(int64)": np.int64}

def _init(self, onnx_path, *, build_options=None, stream=None, cache_dir=None, force_rebuild=False,
          logger_severity="INFO", build_progress_monitor=None):
    self._closed = False
    so = ort.SessionOptions(); so.intra_op_num_threads = 4
    self._sess = ort.InferenceSession(str(onnx_path), so, providers=["CPUExecutionProvider"])
    specs = list(self.contract.tensor_specs)
    self._tensor_specs = MappingProxyType({s.name: s for s in specs})
    self._buffers = {s.name: wp.zeros(s.shape, dtype=wp.dtype_from_numpy(s.dtype), device="cpu") for s in specs}
    self._cuda_graph = None

def _enqueue(self):
    feeds = {i.name: self._buffers[i.name].numpy() for i in self._sess.get_inputs()}
    outs = self._sess.run(None, feeds)
    for o, v in zip(self._sess.get_outputs(), outs):
        self._buffers[o.name].assign(wp.array(np.ascontiguousarray(v), dtype=self._buffers[o.name].dtype, device="cpu"))

ie.InferenceEngine.__init__ = _init
ie.InferenceEngine.device = property(lambda self: wp.get_device("cpu"))
ie.InferenceEngine.stream = property(lambda self: None)
ie.InferenceEngine.enqueue_async = _enqueue
ie.InferenceEngine.synchronize = lambda self: None
ie.InferenceEngine.bake_cuda_graph = lambda self: None
ie.InferenceEngine._discard_resources = lambda self, synchronize: self._buffers.clear()

class _Timer:
    def __init__(self, stream): self.milliseconds = {}
    @contextmanager
    def stage(self, name): yield
    def read(self): pass
me.GenerationTimer = _Timer
gen.GenerationTimer = _Timer
