from datetime import datetime
import os

import click
from slack_sdk.errors import SlackApiError
from slack_sdk.webhook import WebhookClient


@click.command()
@click.option("--job", type=str, help="Job name")
@click.option("--slack", is_flag=True, help="Send message to slack")
def main(job, slack):
    """Demo app printing current time and job name."""

    if job is None:
        text = f"{datetime.now().strftime('%H:%M:%S')}: job is not specified"
    else:
        text = f"{datetime.now().strftime('%H:%M:%S')}: {job} started"

    webhook = WebhookClient(url=os.environ["SLACK_TEST_URL"]) if slack else None
    _echo(text, webhook)


def _echo(text, webhook = None):
    """Send message to slack channel."""

    click.echo(text)

    if webhook is not None:
        try:
            response = webhook.send(text=text)
            assert response.status_code == 200
            assert response.body == "ok"
        except SlackApiError as e:
            assert e.response["error"]
            click.echo(f"Got an error: {e.response['error']}")


if __name__ == "__main__":
    main()
