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

    click.echo(text)

    if slack is not None:
        _send_to_slack(text)


def _send_to_slack(text):
    """Send message to slack channel."""

    webhook = WebhookClient(url=os.environ["SLACK_TEST_URL"])

    try:
        response = webhook.send(text=text)
        assert response.status_code == 200
        assert response.body == "ok"
    except SlackApiError as e:
        assert e.response["error"]
        click.echo(f"Got an error: {e.response['error']}")


if __name__ == "__main__":
    main()
