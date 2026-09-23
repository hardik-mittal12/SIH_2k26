#!/usr/bin/env python3
"""Export the local IndicTrans2 HF checkpoint to a CPU ONNX graph.

Run with the already validated Python 3.11 environment:
  /Users/hardikmittal/models/indictrans311/bin/python tooling/export_indictrans2_onnx.py \
    --model-dir /Users/hardikmittal/models/indictrans2 --output-dir /private/tmp/indictrans2-onnx

The output is FP32 on purpose. Do not quantize before parity is established.
"""
import argparse
import importlib
from pathlib import Path

import torch
from transformers import AutoModelForSeq2SeqLM, AutoTokenizer
from transformers.onnx.convert import export


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--model-dir", type=Path, required=True)
    parser.add_argument("--output-dir", type=Path, required=True)
    parser.add_argument("--opset", type=int, default=17)
    args = parser.parse_args()

    args.output_dir.mkdir(parents=True, exist_ok=True)
    tokenizer = AutoTokenizer.from_pretrained(args.model_dir, trust_remote_code=True)
    model = AutoModelForSeq2SeqLM.from_pretrained(
        args.model_dir,
        trust_remote_code=True,
        torch_dtype=torch.float32,
    ).cpu().eval()
    model.config.use_cache = False
    module = importlib.import_module(type(model.config).__module__)
    onnx_config = module.IndicTransOnnxConfig(
        model.config,
        task="seq2seq-lm",
        use_past=False,
    )
    export(
        preprocessor=tokenizer,
        model=model,
        config=onnx_config,
        opset=args.opset,
        output=args.output_dir / "indictrans2.onnx",
        device="cpu",
    )


if __name__ == "__main__":
    main()
