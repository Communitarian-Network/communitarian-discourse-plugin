export default function getResolutionPeriod(created, closed) {
  const [creationMonth, creationDate, closeMonth, closeDate] = [
    created.format("MMM"),
    created.date(),
    closed.format("MMM"),
    closed.date(),
  ];

  const actionPeriod = [creationMonth, creationDate, "-"];
  if (creationMonth !== closeMonth) {
    actionPeriod.push(closeMonth);
  }
  actionPeriod.push(closeDate);

  return actionPeriod.join(" ");
}
