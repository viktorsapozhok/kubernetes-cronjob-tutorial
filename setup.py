from setuptools import setup


def get_requirements():
    r = []
    with open("requirements.txt") as fp:
        for line in fp.read().split("\n"):
            if not line.startswith("#"):
                r += [line.strip()]
    return r


setup(
    name="app",
    packages=["app"],
    include_package_data=True,
    zip_safe=False,
    install_requires=get_requirements(),
    entry_points={
        "console_scripts": [
            "myapp=app.cli:main",
        ]
    },
)
