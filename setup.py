from setuptools import setup

setup(
    name="app",
    packages=["app"],
    include_package_data=True,
    zip_safe=False,
    install_requires=[
        "click"
    ],
    entry_points={
        "console_scripts": [
            "myapp=app.cli:main",
        ]
    },
)