#!/usr/bin/env python3
"""Build per-direction ONNX Runtime Extensions SentencePiece tokenizer graphs.

The generated graphs map SentencePiece IDs to IndicTrans2's pruned vocabulary
IDs and add the required source/target language tags plus EOS. Android executes
these with `onnxruntime-extensions-android`; no Python tokenizer is shipped.
"""
import argparse
import json
from pathlib import Path

import numpy as np
import onnx
from onnx import TensorProto, helper, numpy_helper
import sentencepiece as spm


def build(model_dir: Path, output: Path, source: str, target: str) -> None:
    src_spm = spm.SentencePieceProcessor(model_file=str(model_dir / "model.SRC"))
    src_vocab = json.loads((model_dir / "dict.SRC.json").read_text())
    mapping = np.full(src_spm.vocab_size(), src_vocab["<unk>"], dtype=np.int64)
    for sp_id in range(src_spm.vocab_size()):
        mapping[sp_id] = src_vocab.get(src_spm.id_to_piece(sp_id), src_vocab["<unk>"])
    prefix = np.array([src_vocab[source], src_vocab[target]], dtype=np.int64)
    eos = np.array([src_vocab["</s>"]], dtype=np.int64)
    initializers = [
        numpy_helper.from_array(mapping, "sp_to_indictrans"),
        numpy_helper.from_array(prefix, "language_prefix"),
        numpy_helper.from_array(eos, "eos"),
        numpy_helper.from_array(np.array([0], dtype=np.int64), "axes_0"),
        numpy_helper.from_array(np.array([0], dtype=np.int64), "nbest_size"),
        numpy_helper.from_array(np.array([0.0], dtype=np.float32), "alpha"),
        numpy_helper.from_array(np.array([False], dtype=np.bool_), "false"),
    ]
    nodes = [
        helper.make_node(
            "SentencepieceTokenizer",
            ["text", "nbest_size", "alpha", "false", "false", "false"],
            ["indices", "sp_ids"],
            domain="ai.onnx.contrib",
            model=(model_dir / "model.SRC").read_bytes(),
        ),
        helper.make_node("Cast", ["sp_ids"], ["sp_ids_i64"], to=TensorProto.INT64),
        helper.make_node("Gather", ["sp_to_indictrans", "sp_ids_i64"], ["token_ids"], axis=0),
        helper.make_node("Concat", ["language_prefix", "token_ids", "eos"], ["flat_input_ids"], axis=0),
        helper.make_node("Unsqueeze", ["flat_input_ids", "axes_0"], ["input_ids"]),
    ]
    graph = helper.make_graph(
        nodes,
        "indictrans2_tokenizer",
        [helper.make_tensor_value_info("text", TensorProto.STRING, [1])],
        [helper.make_tensor_value_info("input_ids", TensorProto.INT64, [1, None])],
        initializers,
    )
    model = helper.make_model(
        graph,
        opset_imports=[helper.make_operatorsetid("", 17), helper.make_operatorsetid("ai.onnx.contrib", 1)],
        producer_name="santali_setu",
    )
    # ORT 1.30 supports ONNX IR v13; ONNX 1.23 defaults to a newer IR.
    model.ir_version = 13
    onnx.checker.check_model(model)
    output.parent.mkdir(parents=True, exist_ok=True)
    onnx.save(model, output)


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--model-dir", type=Path, required=True)
    parser.add_argument("--output-dir", type=Path, required=True)
    args = parser.parse_args()
    build(args.model_dir, args.output_dir / "tokenize_hin_to_sat.onnx", "hin_Deva", "sat_Olck")
    build(args.model_dir, args.output_dir / "tokenize_sat_to_hin.onnx", "sat_Olck", "hin_Deva")


if __name__ == "__main__":
    main()
