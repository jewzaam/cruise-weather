# Future Plans

## Geographic Bounding for Port Suggestions

When building an itinerary, port suggestions should be filtered by geographic feasibility based on the cruise's departure port and the day number being edited.

The idea: if I have a starting port and a destination port, I have a bounding box for how far away ports can be. We can make assumptions about the max speed of a cruise ship. If it were straight-line, no land involved, line of sight between two ports — could a cruise ship at maximum speed (or even double max speed) make it to that port within the days cited on the cruise?

Example: if Day 1 starts in the Netherlands and I click "add port" on Day 2, I shouldn't see results for Florida. Those should not even be an option when I start typing.

This filtering would apply in the ItineraryBuilderSheet port search. It's a low-cost computation — assume no obstacles, straight-line distance, generous speed estimate — that would meaningfully refine the port selection experience.
