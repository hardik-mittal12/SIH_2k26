#!/usr/bin/env python3
"""Compare first-step logits from FP32 PyTorch IndicTrans2 and exported ONNX."""
import argparse
from pathlib import Path

import numpy as np
import onnxruntime as ort
import torch
from transformers import AutoModelForSeq2SeqLM, AutoTokenizer
from IndicTransToolkit.processor import IndicProcessor


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--model-dir", type=Path, required=True)
    parser.add_argument("--onnx", type=Path, required=True)
    args = parser.parse_args()
    tokenizer = AutoTokenizer.from_pretrained(args.model_dir, trust_remote_code=True)
    model = AutoModelForSeq2SeqLM.from_pretrained(
        args.model_dir, trust_remote_code=True, dtype=torch.float32
    ).cpu().eval()
    text = "आप कैसे हैं?"
    batch = IndicProcessor(inference=True).preprocess_batch(
        [text], src_lang="hin_Deva", tgt_lang="sat_Olck"
    )
    encoded = tokenizer(batch, return_tensors="pt", padding=True)
    decoder_ids = torch.tensor([[2]], dtype=torch.long)
    decoder_mask = torch.ones_like(decoder_ids)
    with torch.no_grad():
        torch_logits = model(
            **encoded,
            decoder_input_ids=decoder_ids,
            decoder_attention_mask=decoder_mask,
            use_cache=False,
        ).logits.cpu().numpy()
    session = ort.InferenceSession(str(args.onnx), providers=["CPUExecutionProvider"])
    onnx_logits = session.run(
        ["logits"],
        {
            "input_ids": encoded["input_ids"].numpy().astype(np.int64),
            "attention_mask": encoded["attention_mask"].numpy().astype(np.int64),
            "decoder_input_ids": decoder_ids.numpy().astype(np.int64),
            "decoder_attention_mask": decoder_mask.numpy().astype(np.int64),
        },
    )[0]
    max_abs_error = float(np.max(np.abs(torch_logits - onnx_logits)))
    same_token = int(np.argmax(torch_logits[0, -1])) == int(np.argmax(onnx_logits[0, -1]))
    print(f"max_abs_logit_error={max_abs_error:.8f}")
    print(f"same_next_token={same_token}")
    if not same_token or max_abs_error > 1e-3:
        raise SystemExit("ONNX parity validation failed")


if __name__ == "__main__":
    main()
