https://github.com/bitwalker/timex/issues/460

In my work recently on some appointment scheduling code, I've recently written several functions that work with %Timex.Interval{} structs to decide when someone is available for scheduling. I wondered if you'd be interested in having any of them in the library.

Here's what I've written:

combine/1 takes a list of intervals and combines any that overlap or touch. In our case, the idea is that if someone has availability from 8-9 and 9-10, it's OK to schedule something from 8:30-9:30; we can combine those two intervals into one.
difference/2 is like the set operation - it takes two intervals and removes the second from the first if there's any overlap. It can chop off the beginning or the end, or it can split it into two, so it returns {:ok, list}, which can be empty if it removed the entire interval. We use this for things like "X is available from 8-12 but has an appointment from 9-9:30, so actual availability is 8-9 and 9:30-12."
difference_all/2 takes two lists and removes all of the latter from the former. We use this to take all of a person's availability windows for the day and remove all their existing appointments and such, resulting in a list of their remaining availability.
list_within/3 lists periods of a given length within an interval. So you can say "list all the possible 1-hour appointments between 10-12, starting every 15 minutes" and get back 10-11, 10:15-11:15, 10:30-11:30, 10:45-11:45, 11-12.
I have tests for all of these.

I was unsure exactly what to do about the other attributes: :step, :left_open and :right_open.
What I do right now is when splitting an interval, both new intervals retain the original's other attributes. When combining intervals, we use the other attributes of the first one. When listing intervals within a container interval, we use the other attributes of the container interval.

----
@nathanl It'd be great to add these capabilities to the Interval API! A few thoughts:

I think difference_all can probably be left out, or built as an overload for difference/2 if the second argument is a list of intervals.

I would probably also change list_within/3 to periods/2 where you specify the interval and the unit/span for each period which should be in the resulting list. That said, list_within/3 could instead just be provided by an implementation of Enumerable which would allow converting a period to a list based on the step of the interval, if you need a different step, you just modify the interval and then call to_list/1 on it.

I think I would rename combine/1 to join/2, and make it work like Path.join/2 (perhaps with a corresponding Interval.join/1 which works like Path.join/1).

If you have these completed, feel free to open a PR, and we can either take it from there, or feel free to take the above adjustments into account - either way is fine :)

/cc @ckhrysze
