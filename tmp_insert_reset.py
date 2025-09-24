import pathlib

path = pathlib.Path("src/client/Mobility/MobilityController.luau")
text = path.read_text()
needle = "\tif not self.Humanoid or not self.HumanoidRootPart then\r\n\t\twarn(\"[MobilityController] Failed to find character components\")\r\n\t\treturn\r\n\tend\r\n\t\r\n\t-- Store original FOV when character loads\r\n"
replacement = "\tif not self.Humanoid or not self.HumanoidRootPart then\r\n\t\twarn(\"[MobilityController] Failed to find character components\")\r\n\t\treturn\r\n\tend\r\n\r\n\tself.JumpRequestArmed = false\r\n\tself.IsJumpButtonDown = false\r\n\r\n\t-- Store original FOV when character loads\r\n"
if needle not in text:
    raise RuntimeError("pattern not found")
path.write_text(text.replace(needle, replacement, 1))
