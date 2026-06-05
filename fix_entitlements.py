with open('ios/Runner.xcodeproj/project.pbxproj', 'r', encoding='utf-8') as f:
    content = f.read()

# Normalise to LF for matching
content_lf = content.replace('\r\n', '\n')

before = content_lf.count('CODE_SIGN_ENTITLEMENTS')

content_lf = content_lf.replace(
    'SWIFT_OPTIMIZATION_LEVEL = "-Onone";\n\t\t\t\tSWIFT_VERSION = 5.0;\n\t\t\t\tVERSIONING_SYSTEM = "apple-generic";\n\t\t\t};\n\t\t\tname = Debug;',
    'CODE_SIGN_ENTITLEMENTS = Runner/Runner.entitlements;\n\t\t\t\tSWIFT_OPTIMIZATION_LEVEL = "-Onone";\n\t\t\t\tSWIFT_VERSION = 5.0;\n\t\t\t\tVERSIONING_SYSTEM = "apple-generic";\n\t\t\t};\n\t\t\tname = Debug;'
)

for name in ['Profile', 'Release']:
    content_lf = content_lf.replace(
        'SWIFT_VERSION = 5.0;\n\t\t\t\tVERSIONING_SYSTEM = "apple-generic";\n\t\t\t};\n\t\t\tname = ' + name + ';',
        'CODE_SIGN_ENTITLEMENTS = Runner/Runner.entitlements;\n\t\t\t\tSWIFT_VERSION = 5.0;\n\t\t\t\tVERSIONING_SYSTEM = "apple-generic";\n\t\t\t};\n\t\t\tname = ' + name + ';'
    )

after = content_lf.count('CODE_SIGN_ENTITLEMENTS')

with open('ios/Runner.xcodeproj/project.pbxproj', 'w', encoding='utf-8', newline='\n') as f:
    f.write(content_lf)

print(f'Done: added {after - before} entries ({after} total)')
