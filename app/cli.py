from datetime import datetime

import click


@click.command()
@click.option("--job", type=str, help="Job name")
def main(job):
    """Demo app printing current time to stdout.
    """

    if job is None:
        click.echo(f"{datetime.now().strftime('%H:%M:%S')}: job is not specified")
    else:
        click.echo(f"{datetime.now().strftime('%H:%M:%S')}: {job} started")


if __name__ == "__main__":
    main()
