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
import fcntl

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
        try:
            os.fsync(dir_fd)
        except OSError:
            pass
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


MAX_CONFIG_SIZE = 1024 * 1024  # 1 MB cap for configuration files


def get_verified_path_dir_fd(dir_path: str):
    """
    Traverses and opens each path component starting from root without following symlinks.
    Validates ownership (current user or root) and ensures directory permissions are secure.
    """
    abs_path = os.path.abspath(dir_path)
    cur_fd = os.open("/", os.O_RDONLY | os.O_DIRECTORY | getattr(os, "O_CLOEXEC", 0))
    parts = abs_path.strip("/").split("/") if abs_path.strip("/") else []
    try:
        for part in parts:
            next_fd = os.open(
                part,
                os.O_RDONLY | os.O_DIRECTORY | getattr(os, "O_NOFOLLOW", 0) | getattr(os, "O_CLOEXEC", 0),
                dir_fd=cur_fd,
            )
            os.close(cur_fd)
            cur_fd = next_fd
            st = os.fstat(cur_fd)
            if not stat.S_ISDIR(st.st_mode):
                raise OSError(f"'{part}' is not a directory")
            if st.st_uid != 0 and st.st_uid != os.getuid():
                raise OSError(f"'{part}' is not owned by current user or root (uid {st.st_uid})")
            if (st.st_mode & 0o002) and not (st.st_mode & stat.S_ISVTX):
                raise OSError(f"'{part}' has unsafe world-writable permissions ({oct(st.st_mode)})")
        return cur_fd
    except Exception:
        os.close(cur_fd)
        raise


def safe_update_config(dir_path: str, filename: str, updater_fn, max_retries: int = 5) -> bool:
    """
    Safely reads and modifies an existing configuration file with descriptor safety,
    transaction locking, version-bound compare-and-swap (CAS) revalidation, and directory fsync.
    Uses descriptor-safe operations:
    - O_NOFOLLOW | O_NONBLOCK ensures symlinks and FIFOs never redirect or block operations.
    - fstat validates regular file, user ownership, and size bounds.
    - Acquires advisory lock and checks version identity (dev, ino, mtime, size, content)
      immediately prior to replacing the entry.
    - If target changed concurrently, retries with updated content up to max_retries.
    - Writes to an exclusive temporary file within dir_fd and replaces atomically relative to dir_fd.
    - fsyncs both the temporary file and the held directory descriptor.
    """
    dir_fd = None
    try:
        try:
            dir_fd = get_verified_path_dir_fd(dir_path)
        except Exception:
            return False

        open_flags = (
            os.O_RDONLY
            | getattr(os, "O_NOFOLLOW", 0)
            | getattr(os, "O_NONBLOCK", 0)
            | getattr(os, "O_CLOEXEC", 0)
        )

        for _ in range(max_retries):
            file_fd = None
            temp_fd = None
            temp_name = None
            check_fd = None
            try:
                try:
                    file_fd = os.open(filename, open_flags, dir_fd=dir_fd)
                except (FileNotFoundError, OSError):
                    return False

                # Hold advisory transaction lock if possible
                try:
                    fcntl.flock(file_fd, fcntl.LOCK_EX | fcntl.LOCK_NB)
                except (BlockingIOError, OSError):
                    pass

                st = os.fstat(file_fd)
                if not stat.S_ISREG(st.st_mode):
                    return False
                if st.st_uid != os.getuid():
                    return False
                if st.st_size > MAX_CONFIG_SIZE:
                    return False

                raw_bytes = os.read(file_fd, MAX_CONFIG_SIZE + 1)
                if len(raw_bytes) > MAX_CONFIG_SIZE:
                    return False

                orig_content = raw_bytes.decode("utf-8", errors="replace")
                orig_mode = st.st_mode & 0o777

                new_content = updater_fn(orig_content)
                if new_content is None or new_content == orig_content:
                    return False

                temp_name = f".{filename}.tmp.{os.getpid()}.{secrets.token_hex(8)}"
                temp_flags = (
                    os.O_WRONLY
                    | os.O_CREAT
                    | os.O_EXCL
                    | getattr(os, "O_NOFOLLOW", 0)
                    | getattr(os, "O_CLOEXEC", 0)
                )
                temp_fd = os.open(temp_name, temp_flags, orig_mode, dir_fd=dir_fd)
                st_tmp = os.fstat(temp_fd)
                if not stat.S_ISREG(st_tmp.st_mode) or st_tmp.st_uid != os.getuid():
                    return False

                payload = new_content.encode("utf-8")
                total_written = 0
                while total_written < len(payload):
                    n = os.write(temp_fd, payload[total_written:])
                    if n <= 0:
                        return False
                    total_written += n

                os.fsync(temp_fd)
                os.close(temp_fd)
                temp_fd = None

                # Version-bound compare-and-swap / revalidation immediately before replacement
                try:
                    check_fd = os.open(filename, open_flags, dir_fd=dir_fd)
                except (FileNotFoundError, OSError):
                    return False

                st_check = os.fstat(check_fd)
                if (
                    not stat.S_ISREG(st_check.st_mode)
                    or st_check.st_uid != os.getuid()
                    or st_check.st_dev != st.st_dev
                    or st_check.st_ino != st.st_ino
                    or st_check.st_size != st.st_size
                    or st_check.st_mtime_ns != st.st_mtime_ns
                ):
                    # Target changed concurrently; clean up and retry
                    continue

                check_bytes = os.read(check_fd, MAX_CONFIG_SIZE + 1)
                if check_bytes != raw_bytes:
                    # Target content changed concurrently; clean up and retry
                    continue

                # Atomically replace while descriptors and transaction locks remain held
                os.replace(temp_name, filename, src_dir_fd=dir_fd, dst_dir_fd=dir_fd)
                temp_name = None

                try:
                    os.fsync(dir_fd)
                except OSError:
                    pass

                return True
            finally:
                if check_fd is not None:
                    try:
                        os.close(check_fd)
                    except OSError:
                        pass
                if file_fd is not None:
                    try:
                        os.close(file_fd)
                    except OSError:
                        pass
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
        return False
    except Exception as e:
        print(f"Error updating config {filename}: {e}", file=sys.stderr)
        return False
    finally:
        if dir_fd is not None:
            try:
                os.close(dir_fd)
            except OSError:
                pass


def update_hypr_rule(dir_path: str, filename: str = "hyprland.lua") -> bool:
    def _add_rule(content: str):
        if '"alcalc"' in content:
            return content
        rule = '\n-- Alcalc floating window rule\no.window("alcalc", { float = true })\n'
        return content + rule

    return safe_update_config(dir_path, filename, _add_rule)


def register_shell_plugin(dir_path: str, filename: str = "shell.json") -> bool:
    def _add_plugin(content: str):
        try:
            data = json.loads(content)
        except Exception:
            return None
        bar_layout = data.setdefault("bar", {}).setdefault("layout", {})
        right_list = bar_layout.setdefault("right", [])
        ids = [item.get("id") if isinstance(item, dict) else item for item in right_list]
        if "dorneles.alcalc" not in ids:
            right_list.insert(0, {"id": "dorneles.alcalc"})
            return json.dumps(data, indent=2) + "\n"
        return content

    return safe_update_config(dir_path, filename, _add_plugin)


def unregister_shell_plugin(dir_path: str, filename: str = "shell.json") -> bool:
    def _remove_plugin(content: str):
        try:
            data = json.loads(content)
        except Exception:
            return None
        modified = False
        for section in ["left", "center", "right"]:
            arr = data.get("bar", {}).get("layout", {}).get(section, [])
            new_arr = [item for item in arr if (item.get("id") if isinstance(item, dict) else item) != "dorneles.alcalc"]
            if len(new_arr) != len(arr):
                data["bar"]["layout"][section] = new_arr
                modified = True
        if modified:
            return json.dumps(data, indent=2) + "\n"
        return content

    return safe_update_config(dir_path, filename, _remove_plugin)


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
        print("Commands: read-history, read-vars, read-all, write-history, write-vars, write-state, clear-history, clear-vars, configure-hypr, configure-shell, unconfigure-shell", file=sys.stderr)
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
    elif cmd == "configure-hypr":
        dir_path = sys.argv[2] if len(sys.argv) > 2 else os.path.expanduser("~/.config/hypr")
        filename = sys.argv[3] if len(sys.argv) > 3 else "hyprland.lua"
        success = update_hypr_rule(dir_path, filename)
        if success:
            print("✓ Configured Alcalc floating window rule in Hyprland")
        sys.exit(0)
    elif cmd == "configure-shell":
        dir_path = sys.argv[2] if len(sys.argv) > 2 else os.path.expanduser("~/.config/omarchy")
        filename = sys.argv[3] if len(sys.argv) > 3 else "shell.json"
        success = register_shell_plugin(dir_path, filename)
        if success:
            print("✓ Registered dorneles.alcalc in Omarchy bar layout (shell.json)")
        sys.exit(0)
    elif cmd == "unconfigure-shell":
        dir_path = sys.argv[2] if len(sys.argv) > 2 else os.path.expanduser("~/.config/omarchy")
        filename = sys.argv[3] if len(sys.argv) > 3 else "shell.json"
        success = unregister_shell_plugin(dir_path, filename)
        if success:
            print("✓ Removed dorneles.alcalc from Omarchy bar layout")
        sys.exit(0)
    else:
        print(f"Unknown command: {cmd}", file=sys.stderr)
        sys.exit(1)


if __name__ == "__main__":
    main()
