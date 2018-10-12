defmodule CoachDomain.Interval do
  @moduledoc """
  Works with Timex.Interval structs and extends the functionality of that
  module for our needs.
  """
  @type interval_list :: list(Interval.t())

  alias Timex.Interval

  @doc """
  Generates a list of intervals of the given length which fit inside the
  container interval, starting every N minutes

  ## Examples

  # "During this window of availability, list all the 1-hour slots, starting every 15 minutes."
  iex> CoachDomain.Interval.list_within(Timex.Interval.new(from: ~N[2018-08-16 00:00:00], until: ~N[2018-08-16 01:30:00]), 60, 15)
  [
    Timex.Interval.new(
     from: ~N[2018-08-16 00:00:00],
     until: ~N[2018-08-16 01:00:00]
    ),
    Timex.Interval.new(
     from: ~N[2018-08-16 00:15:00],
     until: ~N[2018-08-16 01:15:00]
    ),
    Timex.Interval.new(
     from: ~N[2018-08-16 00:30:00],
     until: ~N[2018-08-16 01:30:00]
    )
  ]

  """
  @spec list_within(Interval.t(), integer, integer) :: [Interval.t()]
  def list_within(%Timex.Interval{} = container_interval, length_minutes, offset_minutes)
      when is_integer(length_minutes) do
    do_list_within(container_interval, length_minutes, offset_minutes, [])
    |> Enum.reverse()
  end

  defp do_list_within(container_interval, length_minutes, offset_minutes, acc) do
    new_interval =
      case acc do
        [] ->
          container_interval
          |> Map.put(:until, Timex.shift(container_interval.from, minutes: length_minutes))

        [last_built | _others_built] ->
          last_built
          |> Map.put(:from, Timex.shift(last_built.from, minutes: offset_minutes))
          |> Map.put(:until, Timex.shift(last_built.until, minutes: offset_minutes))
      end

    if container_interval |> Timex.Interval.contains?(new_interval) do
      new_acc = [new_interval | acc]
      do_list_within(container_interval, length_minutes, offset_minutes, new_acc)
    else
      acc
    end
  end

  @doc """
  Given a list of intervals, sorts them by :from and walks through them,
  combining those that overlap or touch and leaving the rest unaltered.

  Eg, if a coach is available from 8-9 and also from 9-10, we can consider them
  available from 8-10, and it's OK to schedule an appointment from 8:30-9:30,
  even though that would not have fit within either of the original
  availability intervals.
  """
  def combine(intervals) when is_list(intervals) do
    intervals
    |> Enum.sort_by(& &1.from)
    |> do_combine([])
    |> Enum.reverse()
  end

  defp do_combine([] = _inputs, outputs) do
    outputs
  end

  defp do_combine([first_i | other_is], results) do
    if Enum.empty?(other_is) do
      [first_i | results]
    else
      [next_i | still_more_is] = other_is

      if combinable?(first_i, next_i) do
        combined_i = Map.put(first_i, :until, next_i.until)
        do_combine([combined_i | still_more_is], results)
      else
        do_combine(other_is, [first_i | results])
      end
    end
  end

  defp combinable?(%Timex.Interval{} = i1, %Timex.Interval{} = i2) do
    Timex.Interval.overlaps?(i1, i2) || i1.until == i2.from
  end

  @doc """
  Given an interval, and another interval to subtract from it, returns a
  (possibly empty) list of intervals with that time period removed.

  Subtracting the second interval will have no effect if they don't overlap.
  If they do overlap, subtracting the second interval could chop off the
  beginning of the interval, chop off the end, split it in two (which is why
  this function returns a list of intervals), or eliminate it entirely (in
  which case the list will be empty).
  """
  @spec difference(Interval.t(), Interval.t()) :: [Interval.t()]
  def difference(%Interval{} = i1, %Interval{} = i2) do
    cond do
      i2 |> Timex.Interval.contains?(i1) ->
        {:ok, []}

      i2 |> splits?(i1) ->
        {:ok,
         [
           %Timex.Interval{} =
             Timex.Interval.new(
               from: i1.from,
               until: i2.from,
               left_open: i1.left_open,
               right_open: i1.right_open,
               step: i1.step
             ),
           %Timex.Interval{} =
             Timex.Interval.new(
               from: i2.until,
               until: i1.until,
               left_open: i1.left_open,
               right_open: i1.right_open,
               step: i1.step
             )
         ]}

      i2 |> overlaps_end_of?(i1) ->
        {:ok,
         [
           %Timex.Interval{} =
             Timex.Interval.new(
               from: i1.from,
               until: i2.from,
               left_open: i1.left_open,
               right_open: i1.right_open,
               step: i1.step
             )
         ]}

      i2 |> overlaps_start_of?(i1) ->
        {:ok,
         [
           %Timex.Interval{} =
             Timex.Interval.new(
               from: i2.until,
               until: i1.until,
               left_open: i1.left_open,
               right_open: i1.right_open,
               step: i1.step
             )
         ]}

      # i2 doesn't intersect i1 at all
      true ->
        {:ok, [i1]}
    end
  end

  @doc """
  Given a list of intervals, and a list of intervals to remove from those,
  returns a new list of intervals that don't include the times in the removal
  list.

  For example, if the first list is intervals when a coach has default
  availability, and the second list is a list of intervals when the coach has
  existing appointments, the returned list will have intervals representing
  periods of the coach's default availability when they do not have an
  appointment.
  """
  @spec difference_all([Interval.t()], [Interval.t()]) :: [Interval.t()]
  def difference_all(intervals, intervals_to_remove)
      when is_list(intervals) and is_list(intervals_to_remove) do
    {:ok,
     Enum.flat_map(intervals, fn interval ->
       %Timex.Interval{} = interval
       {:ok, results} = do_difference_all(interval, intervals_to_remove)
       results
     end)}
  end

  defp do_difference_all(%Timex.Interval{} = interval, [
         %Timex.Interval{} = interval_to_remove | more_to_remove
       ]) do
    case difference(interval, interval_to_remove) do
      {:ok, []} ->
        {:ok, []}

      {:ok, [trimmed]} ->
        do_difference_all(trimmed, more_to_remove)

      {:ok, [split_1, split_2]} ->
        {:ok, left} = do_difference_all(split_1, more_to_remove)
        {:ok, right} = do_difference_all(split_2, more_to_remove)
        {:ok, left ++ right}
    end
  end

  defp do_difference_all(%Timex.Interval{} = interval, [] = _intervals_to_remove) do
    {:ok, [interval]}
  end

  defp splits?(i1, i2) do
    i1 |> starts_after_start_of?(i2) && i1 |> ends_before_end_of?(i2)
  end

  defp overlaps_end_of?(i1, i2) do
    i1 |> starts_after_start_of?(i2) && i1 |> starts_at_or_before_end_of?(i2) &&
      i1 |> ends_at_or_after_end_of?(i2)
  end

  defp overlaps_start_of?(i1, i2) do
    i1 |> starts_at_or_before_start_of?(i2) && i1 |> ends_after_start_of?(i2) &&
      i1 |> ends_at_or_before_end_of?(i2)
  end

  defp ends_after_start_of?(i1, i2) do
    Timex.compare(i1.until, i2.from) == 1
  end

  defp ends_at_or_after_end_of?(i1, i2) do
    Timex.compare(i1.until, i2.until) in [0, 1]
  end

  defp ends_at_or_before_end_of?(i1, i2) do
    Timex.compare(i1.until, i2.until) in [-1, 0]
  end

  defp ends_before_end_of?(i1, i2) do
    Timex.compare(i1.until, i2.until) == -1
  end

  defp starts_after_start_of?(i1, i2) do
    Timex.compare(i1.from, i2.from) == 1
  end

  defp starts_at_or_before_end_of?(i1, i2) do
    Timex.compare(i1.from, i2.until) in [-1, 0]
  end

  defp starts_at_or_before_start_of?(i1, i2) do
    Timex.compare(i1.from, i2.from) in [-1, 0]
  end
end
