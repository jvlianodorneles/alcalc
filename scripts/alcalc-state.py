#!/usr/bin/env python3
"""
alcalc-state.py — Bounded descriptor-safe state helper for Alcalc.
Provides atomic, non-blocking, symlink-safe reads and writes for history and variables.
"""

import sys
import os
import json
import stat
import secrets

MAX_STATE_SIZE = 512 * 1024  # 512 KB cap to prevent DoS / unbounded memory consumption
STATE_DIR = os.path.expanduser("~/.local/state/omarchy/alcalc")


def get_verified_state_dir_fd():
    """
    Creates (if needed), opens, and strictly verifies the STATE_DIR descriptor.
    Refuses symlinks, foreign-owned directories, or insecure world-writable permissions.
    """
    os.makedirs(STATE_DIR, mode=0o700, exist_ok=True)
    flags = os.O_RDONLY | os.O_DIRECTORY | getattr(os, "O_NOFOLLOW", 0) | getattr(os, "O_CLOEXEC", 0)
    dir_fd = os.open(STATE_DIR, flags)
    try:
        st = os.fstat(dir_fd)
        if not stat.S_ISDIR(st.st_mode):
            raise OSError(f"STATE_DIR '{STATE_DIR}' is not a directory")
        if st.st_uid != os.getuid():
            raise OSError(f"STATE_DIR '{STATE_DIR}' is not owned by current user (uid {st.st_uid} != {os.getuid()})")
        if st.st_mode & 0o002:
            raise OSError(f"STATE_DIR '{STATE_DIR}' has unsafe world-writable permissions ({oct(st.st_mode)})")
        return dir_fd
    except Exception:
        os.close(dir_fd)
        raise


def safe_read_file(filename: str, default_val):
    """
    Safely reads JSON file using non-blocking, no-follow descriptor open,
    fstat validation (regular file, ownership, size cap), and bounded read.
    """
    dir_fd = None
    fd = None
    try:
        dir_fd = get_verified_state_dir_fd()
        open_flags = (
            os.O_RDONLY
            | getattr(os, "O_NOFOLLOW", 0)
            | getattr(os, "O_NONBLOCK", 0)
            | getattr(os, "O_CLOEXEC", 0)
        )
        try:
            fd = os.open(filename, open_flags, dir_fd=dir_fd)
        except (FileNotFoundError, OSError):
            return default_val

        st = os.fstat(fd)
        # Verify regular file type
        if not stat.S_ISREG(st.st_mode):
            return default_val
        # Verify ownership
        if st.st_uid != os.getuid():
            return default_val
        # Verify size cap
        if st.st_size > MAX_STATE_SIZE:
            return default_val

        raw_bytes = os.read(fd, MAX_STATE_SIZE + 1)
        if len(raw_bytes) > MAX_STATE_SIZE:
            return default_val

        if not raw_bytes.strip():
            return default_val

        data = json.loads(raw_bytes.decode("utf-8"))
        if isinstance(default_val, list) and not isinstance(data, list):
            return default_val
        if isinstance(default_val, dict) and not isinstance(data, dict):
            return default_val

        return data
    except Exception:
        return default_val
    finally:
        if fd is not None:
            try:
                os.close(fd)
            except OSError:
                pass
        if dir_fd is not None:
            try:
                os.close(dir_fd)
            except OSError:
                pass


def safe_write_file(filename: str, data, is_list: bool = False):
    """
    Safely writes JSON file using exclusive temporary file creation,
    fstat validation, bounded write, fsync, and atomic replace relative to dir_fd.
    """
    dir_fd = None
    temp_fd = None
    temp_name = None
    try:
        if is_list and not isinstance(data, list):
            raise ValueError(f"Expected list for {filename}")
        elif not is_list and not isinstance(data, dict):
            raise ValueError(f"Expected dict for {filename}")

        payload_bytes = json.dumps(data, indent=2, ensure_ascii=False).encode("utf-8")
        if len(payload_bytes) > MAX_STATE_SIZE:
            raise ValueError(f"Payload size {len(payload_bytes)} exceeds maximum {MAX_STATE_SIZE} bytes")

        dir_fd = get_verified_state_dir_fd()
        temp_name = f".{filename}.tmp.{os.getpid()}.{secrets.token_hex(8)}"
        temp_flags = (
            os.O_WRONLY
            | os.O_CREAT
            | os.O_EXCL
            | getattr(os, "O_NOFOLLOW", 0)
            | getattr(os, "O_CLOEXEC", 0)
        )
        temp_fd = os.open(temp_name, temp_flags, 0o600, dir_fd=dir_fd)

        st = os.fstat(temp_fd)
        if not stat.S_ISREG(st.st_mode) or st.st_uid != os.getuid():
            raise OSError("Insecure temporary file attributes")

        total_written = 0
        while total_written < len(payload_bytes):
            n = os.write(temp_fd, payload_bytes[total_written:])
            if n <= 0:
                raise OSError("Write to temp file failed")
            total_written += n

        os.fsync(temp_fd)
        os.close(temp_fd)
        temp_fd = None

        os.replace(temp_name, filename, src_dir_fd=dir_fd, dst_dir_fd=dir_fd)
        temp_name = None
        return True
    except Exception as e:
        print(f"Error writing {filename}: {e}", file=sys.stderr)
        return False
    finally:
        if temp_fd is not None:
            try:
                os.close(temp_fd)
            except OSError:
                pass
        if temp_name is not None and dir_fd is not None:
            try:
                os.unlink(temp_name, dir_fd=dir_fd)
            except OSError:
                pass
        if dir_fd is not None:
            try:
                os.close(dir_fd)
            except OSError:
                pass


def parse_input_json(raw: str, default_val):
    if not raw or raw.strip() == "":
        return default_val
    try:
        return json.loads(raw)
    except Exception:
        return default_val


def main():
    if len(sys.argv) < 2:
        print("Usage: alcalc-state.py <command> [args...]", file=sys.stderr)
        print("Commands: read-history, read-vars, read-all, write-history, write-vars, write-state, clear-history, clear-vars", file=sys.stderr)
        sys.exit(1)

    cmd = sys.argv[1]

    if cmd == "read-history":
        hist = safe_read_file("history.json", [])
        print(json.dumps(hist, ensure_ascii=False))
    elif cmd == "read-vars":
        vars_map = safe_read_file("vars.json", {})
        print(json.dumps(vars_map, ensure_ascii=False))
    elif cmd == "read-all":
        hist = safe_read_file("history.json", [])
        vars_map = safe_read_file("vars.json", {})
        print(json.dumps({"history": hist, "vars": vars_map}, ensure_ascii=False))
    elif cmd == "write-history":
        raw = sys.argv[2] if len(sys.argv) > 2 else sys.stdin.read()
        data = parse_input_json(raw, [])
        if not isinstance(data, list):
            data = []
        success = safe_write_file("history.json", data, is_list=True)
        sys.exit(0 if success else 1)
    elif cmd == "write-vars":
        raw = sys.argv[2] if len(sys.argv) > 2 else sys.stdin.read()
        data = parse_input_json(raw, {})
        if not isinstance(data, dict):
            data = {}
        success = safe_write_file("vars.json", data, is_list=False)
        sys.exit(0 if success else 1)
    elif cmd == "write-state":
        raw_hist = sys.argv[2] if len(sys.argv) > 2 else "[]"
        raw_vars = sys.argv[3] if len(sys.argv) > 3 else "{}"
        hist_data = parse_input_json(raw_hist, [])
        vars_data = parse_input_json(raw_vars, {})
        if not isinstance(hist_data, list):
            hist_data = []
        if not isinstance(vars_data, dict):
            vars_data = {}
        s1 = safe_write_file("history.json", hist_data, is_list=True)
        s2 = safe_write_file("vars.json", vars_data, is_list=False)
        sys.exit(0 if (s1 and s2) else 1)
    elif cmd == "clear-history":
        success = safe_write_file("history.json", [], is_list=True)
        sys.exit(0 if success else 1)
    elif cmd == "clear-vars":
        success = safe_write_file("vars.json", {}, is_list=False)
        sys.exit(0 if success else 1)
    else:
        print(f"Unknown command: {cmd}", file=sys.stderr)
        sys.exit(1)


if __name__ == "__main__":
    main()
