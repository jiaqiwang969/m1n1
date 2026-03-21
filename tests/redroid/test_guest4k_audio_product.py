from pathlib import Path


REPO_ROOT = Path(__file__).resolve().parents[2]
FIXTURE = REPO_ROOT / "tmp" / "test-fixtures" / "redroid.mk"


def _fixture_text() -> str:
    return FIXTURE.read_text()


def test_redroid_product_declares_ranchu_primary_audio_hal() -> None:
    text = _fixture_text()

    assert "android.hardware.audio@7.1-impl.ranchu" in text
    assert "android.hardware.audio.legacy@7.1-impl.ranchu" in text


def test_redroid_product_enables_goldfish_audio_namespace_and_tinyalsa_knobs() -> None:
    text = _fixture_text()

    assert "device/generic/goldfish \\" in text
    assert "ro.hardware.audio.tinyalsa.period_count=4" in text
    assert "ro.hardware.audio.tinyalsa.period_size_multiplier=2" in text
