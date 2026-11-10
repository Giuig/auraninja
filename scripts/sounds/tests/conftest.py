import sys
from pathlib import Path

# scripts/sounds on sys.path so tests can `import build`, `import check`, `from lib import ...`.
sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
sys.path.insert(0, str(Path(__file__).resolve().parent))
