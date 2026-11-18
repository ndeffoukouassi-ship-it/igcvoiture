function loyaltyState(tickets, plate) {
  const normalize = value => String(value).toUpperCase().replace(/[^A-Z0-9]/g, '');
  const vehicle = normalize(plate);
  if (!vehicle) return {count:0, eligible:false};
  let count = 0;
  for (const ticket of tickets) {
    if (normalize(ticket.plate) !== vehicle) continue;
    // A gift consumes the reward immediately, including while the wash is in progress.
    if (ticket.gift) count = 0;
    else if (ticket.status === 'Terminé' && ticket.payment && ticket.amount > 0) count++;
  }
  return {count, eligible:count >= 9};
}
if (typeof module !== 'undefined') module.exports = {loyaltyState};
