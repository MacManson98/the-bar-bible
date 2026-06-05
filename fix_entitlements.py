with open('ios/Runner.xcodeproj/project.pbxproj', 'r', encoding='utf-8') as f:
    content = f.read()

before = content.count('CODE_SIGN_ENTITLEMENTS')

# Try all line ending combinations
replacements = [
    # LF versions
    (
        'SWIFT_OPTIMIZATION_LEVEL = "-Onone";\n\t\t\t\tSWIFT_VERSION = 5.0;\n\t\t\t\tVERSIONING_SYSTEM = "apple-generic";\n\t\t\t};\n\t\t\tname = Debug;',
        'CODE_SIGN_ENTITLEMENTS = Runner/Runner.entitlements;\n\t\t\t\tSWIFT_OPTIMIZATION_LEVEL = "-Onone";\n\t\t\t\tSWIFT_VERSION = 5.0;\n\t\t\t\tVERSIONING_SYSTEM = "apple-generic";\n\t\t\t};\n\t\t\tname = Debug;'
    ),
    (
        'SWIFT_VERSION = 5.0;\n\t\t\t\tVERSIONING_SYSTEM = "apple-generic";\n\t\t\t};\n\t\t\tname = Profile;',
        'CODE_SIGN_ENTITLEMENTS = Runner/Runner.entitlements;\n\t\t\t\tSWIFT_VERSION = 5.0;\n\t\t\t\tVERSIONING_SYSTEM = "apple-generic";\n\t\t\t};\n\t\t\tname = Profile;'
    ),
    (
        'SWIFT_VERSION = 5.0;\n\t\t\t\tVERSIONING_SYSTEM = "apple-generic";\n\t\t\t};\n\t\t\tname = Release;',
        'CODE_SIGN_ENTITLEMENTS = Runner/Runner.entitlements;\n\t\t\t\tSWIFT_VERSION = 5.0;\n\t\t\t\tVERSIONING_SYSTEM = "apple-generic";\n\t\t\t};\n\t\t\tname = Release;'
    ),
    # CRLF versions
    (
        'SWIFT_OPTIMIZATION_LEVEL = "-Onone";\r\n\t\t\t\tSWIFT_VERSION = 5.0;\r\n\t\t\t\tVERSIONING_SYSTEM = "apple-generic";\r\n\t\t\t};\r\n\t\t\tname = Debug;',
        'CODE_SIGN_ENTITLEMENTS = Runner/Runner.entitlements;\r\n\t\t\t\tSWIFT_OPTIMIZATION_LEVEL = "-Onone";\r\n\t\t\t\tSWIFT_VERSION = 5.0;\r\n\t\t\t\tVERSIONING_SYSTEM = "apple-generic";\r\n\t\t\t};\r\n\t\t\tname = Debug;'
    ),
    (
        'SWIFT_VERSION = 5.0;\r\n\t\t\t\tVERSIONING_SYSTEM = "apple-generic";\r\n\t\t\t};\r\n\t\t\tname = Profile;',
        'CODE_SIGN_ENTITLEMENTS = Runner/Runner.entitlements;\r\n\t\t\t\tSWIFT_VERSION = 5.0;\r\n\t\t\t\tVERSIONING_SYSTEM = "apple-generic";\r\n\t\t\t};\r\n\t\t\tname = Profile;'
    ),
    (
        'SWIFT_VERSION = 5.0;\r\n\t\t\t\tVERSIONING_SYSTEM = "apple-generic";\r\n\t\t\t};\r\n\t\t\tname = Release;',
        'CODE_SIGN_ENTITLEMENTS = Runner/Runner.entitlements;\r\n\t\t\t\tSWIFT_VERSION = 5.0;\r\n\t\t\t\tVERSIONING_SYSTEM = "apple-generic";\r\n\t\t\t};\r\n\t\t\tname = Release;'
    ),
]

for old, new in replacements:
    if old in content:
        content = content.replace(old, new)
        print(f'Replaced: ...name = {old.split("name = ")[1][:10]}')

after = content.count('CODE_SIGN_ENTITLEMENTS')

# Write preserving original line endings
with open('ios/Runner.xcodeproj/project.pbxproj', 'w', encoding='utf-8') as f:
    f.write(content)

print(f'Done: added {after - before} entries ({after} total)')
