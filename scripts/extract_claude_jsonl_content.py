#!/usr/bin/env python3
"""Extract useful human-readable content from a Claude JSONL transcript."""

from __future__ import annotations

import argparse
import json
import sys
from pathlib import Path
from typing import Any, Iterable, TextIO


DEFAULT_INPUT = (
    Path.home()
    / ".claude/projects/-Users-marin-decanini-Documents-PROJETS-projet-cloud/"
    / "20c4457d-d711-4f65-8bd6-c3b8556bc49d.jsonl"
)

SKIPPED_BLOCK_TYPES = {"thinking"}
SKIPPED_EVENT_TYPES = {
    "attachment",
    "file-history-snapshot",
    "queue-operation",
    "last-prompt",
    "mode",
}

LANG_BY_SUFFIX = {
    ".cfg": "ini",
    ".conf": "conf",
    ".ini": "ini",
    ".json": "json",
    ".md": "markdown",
    ".py": "python",
    ".sh": "bash",
    ".tf": "hcl",
    ".tex": "latex",
    ".yaml": "yaml",
    ".yml": "yaml",
}


class ExtractOptions:
    def __init__(
        self,
        include_events: bool,
        include_sidechain: bool,
        include_tool_calls: bool,
        include_tool_results: bool,
        include_timestamps: bool,
        max_block_chars: int | None,
    ) -> None:
        self.include_events = include_events
        self.include_sidechain = include_sidechain
        self.include_tool_calls = include_tool_calls
        self.include_tool_results = include_tool_results
        self.include_timestamps = include_timestamps
        self.max_block_chars = max_block_chars


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description=(
            "Extract useful content from a Claude JSONL transcript: user text, "
            "assistant text, tool calls, and tool results."
        )
    )
    parser.add_argument(
        "input",
        nargs="?",
        type=Path,
        default=DEFAULT_INPUT,
        help=f"JSONL transcript to read. Default: {DEFAULT_INPUT}",
    )
    parser.add_argument(
        "-o",
        "--output",
        type=Path,
        help="Write Markdown output to this file instead of stdout.",
    )
    parser.add_argument(
        "--include-events",
        action="store_true",
        help="Also include non-message events such as attachments and snapshots.",
    )
    parser.add_argument(
        "--include-sidechain",
        action="store_true",
        help="Also include sidechain messages.",
    )
    parser.add_argument(
        "--no-tool-calls",
        dest="include_tool_calls",
        action="store_false",
        help="Skip tool call blocks.",
    )
    parser.add_argument(
        "--no-tool-results",
        dest="include_tool_results",
        action="store_false",
        help="Skip tool result blocks.",
    )
    parser.add_argument(
        "--no-timestamps",
        dest="include_timestamps",
        action="store_false",
        help="Do not show timestamps in entry headings.",
    )
    parser.add_argument(
        "--max-block-chars",
        type=int,
        default=0,
        help="Truncate each content block after N characters. 0 means no truncation.",
    )
    parser.set_defaults(include_tool_calls=True, include_tool_results=True, include_timestamps=True)
    return parser.parse_args()


def load_jsonl(path: Path) -> Iterable[tuple[int, dict[str, Any]]]:
    with path.open("r", encoding="utf-8") as handle:
        for line_no, line in enumerate(handle, 1):
            line = line.strip()
            if not line:
                continue
            try:
                value = json.loads(line)
            except json.JSONDecodeError as exc:
                print(f"warning: line {line_no}: invalid JSON: {exc}", file=sys.stderr)
                continue
            if isinstance(value, dict):
                yield line_no, value
            else:
                print(f"warning: line {line_no}: root value is not an object", file=sys.stderr)


def truncate(text: str, max_chars: int | None) -> str:
    if max_chars is None or len(text) <= max_chars:
        return text
    omitted = len(text) - max_chars
    return f"{text[:max_chars]}\n\n[... truncated {omitted} chars ...]"


def code_fence(text: Any, language: str = "", max_chars: int | None = None) -> str:
    if not isinstance(text, str):
        text = json.dumps(text, ensure_ascii=False, indent=2)
    text = truncate(text.rstrip("\n"), max_chars)
    longest = 2
    current = 0
    for char in text:
        if char == "`":
            current += 1
            longest = max(longest, current)
        else:
            current = 0
    fence = "`" * (longest + 1)
    return f"{fence}{language}\n{text}\n{fence}"


def infer_language(file_path: str | None) -> str:
    if not file_path:
        return ""
    return LANG_BY_SUFFIX.get(Path(file_path).suffix.lower(), "")


def as_json_block(value: Any, max_chars: int | None = None) -> str:
    return code_fence(json.dumps(value, ensure_ascii=False, indent=2), "json", max_chars)


def one_line(value: Any) -> str:
    if value is None:
        return ""
    return str(value).replace("\n", " ").strip()


def heading_for_entry(obj: dict[str, Any], line_no: int, options: ExtractOptions) -> str:
    msg = obj.get("message") if isinstance(obj.get("message"), dict) else {}
    role = msg.get("role") or obj.get("type") or "event"
    role_label = str(role).capitalize()
    parts = [f"## {role_label}"]
    if options.include_timestamps and obj.get("timestamp"):
        parts.append(str(obj["timestamp"]))
    parts.append(f"(line {line_no})")
    return " - ".join(parts)


def content_blocks(message: dict[str, Any]) -> list[dict[str, Any]]:
    content = message.get("content")
    if isinstance(content, str):
        return [{"type": "text", "text": content}]
    if isinstance(content, list):
        blocks: list[dict[str, Any]] = []
        for item in content:
            if isinstance(item, dict):
                blocks.append(item)
            elif isinstance(item, str):
                blocks.append({"type": "text", "text": item})
            else:
                blocks.append({"type": type(item).__name__, "value": item})
        return blocks
    return []


def render_tool_call(block: dict[str, Any], options: ExtractOptions) -> list[str]:
    name = one_line(block.get("name")) or "tool"
    tool_input = block.get("input")
    if not isinstance(tool_input, dict):
        return [f"### Tool call: {name}", as_json_block(block, options.max_block_chars)]

    lines = [f"### Tool call: {name}"]
    description = one_line(tool_input.get("description"))
    if description:
        lines.append(f"Description: {description}")

    if name == "Bash" and "command" in tool_input:
        lines.append(code_fence(tool_input.get("command", ""), "bash", options.max_block_chars))
        extra = {k: v for k, v in tool_input.items() if k not in {"command", "description"}}
        if extra:
            lines.append(as_json_block(extra, options.max_block_chars))
        return lines

    if name == "Write" and "content" in tool_input:
        file_path = one_line(tool_input.get("file_path"))
        if file_path:
            lines.append(f"File: `{file_path}`")
        lines.append(code_fence(tool_input.get("content", ""), infer_language(file_path), options.max_block_chars))
        extra = {k: v for k, v in tool_input.items() if k not in {"content", "file_path", "description"}}
        if extra:
            lines.append(as_json_block(extra, options.max_block_chars))
        return lines

    if name == "Edit":
        file_path = one_line(tool_input.get("file_path"))
        if file_path:
            lines.append(f"File: `{file_path}`")
        for key, label in (("old_string", "Old"), ("new_string", "New")):
            if key in tool_input:
                lines.append(f"{label}:")
                lines.append(code_fence(tool_input[key], infer_language(file_path), options.max_block_chars))
        extra = {
            k: v
            for k, v in tool_input.items()
            if k not in {"file_path", "old_string", "new_string", "description"}
        }
        if extra:
            lines.append(as_json_block(extra, options.max_block_chars))
        return lines

    if name == "Read" and "file_path" in tool_input:
        lines.append(f"File: `{one_line(tool_input.get('file_path'))}`")
        extra = {k: v for k, v in tool_input.items() if k not in {"file_path", "description"}}
        if extra:
            lines.append(as_json_block(extra, options.max_block_chars))
        return lines

    if name == "TodoWrite" and isinstance(tool_input.get("todos"), list):
        lines.append(as_json_block(tool_input["todos"], options.max_block_chars))
        return lines

    if name in {"ExitPlanMode"} and isinstance(tool_input.get("plan"), str):
        lines.append(truncate(tool_input["plan"].rstrip("\n"), options.max_block_chars))
        return lines

    return lines + [as_json_block(tool_input, options.max_block_chars)]


def render_tool_result(block: dict[str, Any], obj: dict[str, Any], options: ExtractOptions) -> list[str]:
    lines = ["### Tool result"]
    if block.get("is_error"):
        lines.append("Status: error")

    content = block.get("content")
    if content is None and isinstance(obj.get("toolUseResult"), dict):
        result = obj["toolUseResult"]
        content_parts = []
        if result.get("stdout"):
            content_parts.append(str(result["stdout"]))
        if result.get("stderr"):
            content_parts.append("stderr:\n" + str(result["stderr"]))
        content = "\n\n".join(content_parts)

    if isinstance(content, list):
        for item in content:
            lines.extend(render_generic_block(item, options))
    elif isinstance(content, str):
        lines.append(code_fence(content, "", options.max_block_chars))
    elif content is not None:
        lines.append(as_json_block(content, options.max_block_chars))
    return lines


def render_generic_block(block: Any, options: ExtractOptions) -> list[str]:
    if isinstance(block, str):
        return [truncate(block.rstrip("\n"), options.max_block_chars)]
    if not isinstance(block, dict):
        return [as_json_block(block, options.max_block_chars)]
    block_type = block.get("type")
    if block_type == "text":
        return [truncate(str(block.get("text", "")).rstrip("\n"), options.max_block_chars)]
    if "text" in block and isinstance(block["text"], str):
        return [truncate(block["text"].rstrip("\n"), options.max_block_chars)]
    return [as_json_block(block, options.max_block_chars)]


def render_message_entry(line_no: int, obj: dict[str, Any], options: ExtractOptions) -> list[str]:
    message = obj.get("message")
    if not isinstance(message, dict):
        return []

    rendered: list[str] = []
    for block in content_blocks(message):
        block_type = block.get("type")
        if block_type in SKIPPED_BLOCK_TYPES:
            continue
        if block_type == "tool_use":
            if options.include_tool_calls:
                rendered.extend(render_tool_call(block, options))
            continue
        if block_type == "tool_result":
            if options.include_tool_results:
                rendered.extend(render_tool_result(block, obj, options))
            continue
        rendered.extend(render_generic_block(block, options))

    if not rendered:
        return []
    return [heading_for_entry(obj, line_no, options), *rendered]


def render_event_entry(line_no: int, obj: dict[str, Any], options: ExtractOptions) -> list[str]:
    event_type = obj.get("type")
    if not options.include_events and event_type in SKIPPED_EVENT_TYPES:
        return []
    if not options.include_events and event_type not in {"system"}:
        return []
    return [heading_for_entry(obj, line_no, options), as_json_block(obj, options.max_block_chars)]


def render(path: Path, options: ExtractOptions) -> str:
    parts = [f"# Claude transcript useful content", "", f"Source: `{path}`"]
    for line_no, obj in load_jsonl(path):
        if obj.get("isSidechain") and not options.include_sidechain:
            continue
        if isinstance(obj.get("message"), dict):
            entry = render_message_entry(line_no, obj, options)
        else:
            entry = render_event_entry(line_no, obj, options)
        if entry:
            parts.extend(["", *entry])
    return "\n".join(parts).rstrip() + "\n"


def main() -> int:
    args = parse_args()
    input_path = args.input.expanduser()
    if not input_path.exists():
        print(f"error: file not found: {input_path}", file=sys.stderr)
        return 1

    options = ExtractOptions(
        include_events=args.include_events,
        include_sidechain=args.include_sidechain,
        include_tool_calls=args.include_tool_calls,
        include_tool_results=args.include_tool_results,
        include_timestamps=args.include_timestamps,
        max_block_chars=args.max_block_chars or None,
    )
    output = render(input_path, options)

    if args.output:
        output_path = args.output.expanduser()
        output_path.parent.mkdir(parents=True, exist_ok=True)
        output_path.write_text(output, encoding="utf-8")
    else:
        stream: TextIO = sys.stdout
        stream.write(output)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
