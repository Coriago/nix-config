"""Link only Noctalia settings, never its state directory; refuse data loss."""
import os
from pathlib import Path
import sys


def prepare(destination, target):
    if target is None:
        if destination.is_symlink():
            raise RuntimeError(f"{destination} is still linked to a checkout. Move the link aside before disabling liveConfig.")
        return
    if not target.is_absolute() or not target.is_file():
        raise RuntimeError(f"Live settings file must exist at an absolute path: {target}")
    if destination.is_symlink() and destination.resolve() == target.resolve():
        return
    if os.path.lexists(destination):
        raise RuntimeError(f"Refusing to replace {destination}. Reconcile it with {target}, then move it aside.")
    destination.parent.mkdir(parents=True, exist_ok=True)
    try:
        destination.symlink_to(target)
    except FileExistsError:
        # Two wrapper invocations can start concurrently.
        if not destination.is_symlink() or destination.resolve() != target.resolve():
            raise


if __name__ == "__main__":
    try:
        prepare(Path(sys.argv[1]), Path(sys.argv[2]) if sys.argv[2] else None)
    except (OSError, RuntimeError) as error:
        sys.exit(f"mynoctalia: {error}")
