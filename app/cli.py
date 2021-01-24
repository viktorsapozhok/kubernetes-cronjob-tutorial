from datetime import datetime

import click


@click.group()
def main():
    """Welcome to myApp CLI!
    """


@main.command()
@click.option("--job", type=str, help="Job name")
def run(job):
    """Print job name and current time to stdout.
    """

    if job is None:
        click.echo(f"{datetime.now().strftime('%H:%M:%S')}: job is not specified")
    else:
        click.echo(f"{datetime.now().strftime('%H:%M:%S')}: {job} started")
