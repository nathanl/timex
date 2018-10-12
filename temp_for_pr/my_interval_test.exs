defmodule CoachDomain.IntervalTest do
  use CoachDomain.DataCase, async: true
  doctest CoachDomain.Interval

  def to_dt(%NaiveDateTime{} = ndt) do
    {:ok, dt} = DateTime.from_naive(ndt, "Etc/UTC")
    dt
  end

  describe "list_within/2 builds intervals of given length that fit within given interval" do
    test "can build 1-hour intervals offset every 15 minutes" do
      midnight_to_one_thirty =
        Timex.Interval.new(
          from: ~N[2018-08-16 00:00:00],
          until: ~N[2018-08-16 01:30:00]
        )

      assert CoachDomain.Interval.list_within(midnight_to_one_thirty, 60, 15) == [
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
    end

    test "can build 15-minute intervals offset every 15 minutes" do
      midnight_to_one =
        Timex.Interval.new(
          from: ~N[2018-08-16 00:00:00],
          until: ~N[2018-08-16 01:00:00]
        )

      assert CoachDomain.Interval.list_within(midnight_to_one, 15, 15) == [
               Timex.Interval.new(
                 from: ~N[2018-08-16 00:00:00],
                 until: ~N[2018-08-16 00:15:00]
               ),
               Timex.Interval.new(
                 from: ~N[2018-08-16 00:15:00],
                 until: ~N[2018-08-16 00:30:00]
               ),
               Timex.Interval.new(
                 from: ~N[2018-08-16 00:30:00],
                 until: ~N[2018-08-16 00:45:00]
               ),
               Timex.Interval.new(
                 from: ~N[2018-08-16 00:45:00],
                 until: ~N[2018-08-16 01:00:00]
               )
             ]
    end

    test "can build 15-minute intervals offset every 30 minutes" do
      midnight_to_one_thirty =
        Timex.Interval.new(
          from: ~N[2018-08-16 00:00:00],
          until: ~N[2018-08-16 01:30:00]
        )

      assert CoachDomain.Interval.list_within(midnight_to_one_thirty, 15, 30) == [
               Timex.Interval.new(
                 from: ~N[2018-08-16 00:00:00],
                 until: ~N[2018-08-16 00:15:00]
               ),
               Timex.Interval.new(
                 from: ~N[2018-08-16 00:30:00],
                 until: ~N[2018-08-16 00:45:00]
               ),
               Timex.Interval.new(
                 from: ~N[2018-08-16 01:00:00],
                 until: ~N[2018-08-16 01:15:00]
               )
             ]
    end

    test "won't build an interval that overflows the container" do
      container_interval =
        Timex.Interval.new(
          from: ~N[2018-08-16 00:00:00],
          until: ~N[2018-08-16 02:00:00]
        )

      assert CoachDomain.Interval.list_within(container_interval, 45, 45) == [
               Timex.Interval.new(
                 from: ~N[2018-08-16 00:00:00],
                 until: ~N[2018-08-16 00:45:00]
               ),
               Timex.Interval.new(
                 from: ~N[2018-08-16 00:45:00],
                 until: ~N[2018-08-16 01:30:00]
               )
               # not built; would overflow
               # Timex.Interval.new(
               #   from: ~N[2018-08-16 01:30:00],
               #   until: ~N[2018-08-16 02:15:00]
               # )
             ]

      assert CoachDomain.Interval.list_within(container_interval, 45, 30) == [
               Timex.Interval.new(
                 from: ~N[2018-08-16 00:00:00],
                 until: ~N[2018-08-16 00:45:00]
               ),
               Timex.Interval.new(
                 from: ~N[2018-08-16 00:30:00],
                 until: ~N[2018-08-16 01:15:00]
               ),
               Timex.Interval.new(
                 from: ~N[2018-08-16 01:00:00],
                 until: ~N[2018-08-16 01:45:00]
               )
               # not built; would overflow
               # Timex.Interval.new(
               #   from: ~N[2018-08-16 01:30:00],
               #   until: ~N[2018-08-16 02:15:00]
               # ),
             ]
    end

    test "returns an empty list if no intervals of the given length will fit" do
      container_interval =
        Timex.Interval.new(
          from: ~N[2018-08-16 00:00:00],
          until: ~N[2018-08-16 00:15:00]
        )

      assert CoachDomain.Interval.list_within(container_interval, 30, 30) == []
    end
  end

  describe "combine/1 combines intervals when possible" do
    test "combines overlapping intervals" do
      assert CoachDomain.Interval.combine([
               Timex.Interval.new(
                 from: ~N[2018-08-16 00:00:00],
                 until: ~N[2018-08-16 00:30:00]
               ),
               Timex.Interval.new(
                 from: ~N[2018-08-16 00:15:00],
                 until: ~N[2018-08-16 00:45:00]
               ),
               Timex.Interval.new(
                 from: ~N[2018-08-16 00:30:00],
                 until: ~N[2018-08-16 01:00:00]
               ),
               Timex.Interval.new(
                 from: ~N[2018-08-16 02:00:00],
                 until: ~N[2018-08-16 03:00:00]
               )
             ]) == [
               Timex.Interval.new(
                 from: ~N[2018-08-16 00:00:00],
                 until: ~N[2018-08-16 01:00:00]
               ),
               Timex.Interval.new(
                 from: ~N[2018-08-16 02:00:00],
                 until: ~N[2018-08-16 03:00:00]
               )
             ]
    end

    test "combines touching intervals" do
      assert CoachDomain.Interval.combine([
               Timex.Interval.new(
                 from: ~N[2018-08-16 00:00:00],
                 until: ~N[2018-08-16 00:15:00]
               ),
               Timex.Interval.new(
                 from: ~N[2018-08-16 00:15:00],
                 until: ~N[2018-08-16 00:30:00]
               ),
               Timex.Interval.new(
                 from: ~N[2018-08-16 01:00:00],
                 until: ~N[2018-08-16 01:15:00]
               )
             ]) == [
               Timex.Interval.new(
                 from: ~N[2018-08-16 00:00:00],
                 until: ~N[2018-08-16 00:30:00]
               ),
               Timex.Interval.new(
                 from: ~N[2018-08-16 01:00:00],
                 until: ~N[2018-08-16 01:15:00]
               )
             ]
    end
  end

  describe "difference/2 removes the part of interval 1 that overlaps with interval 2" do
    test "returns a list with the original interval when there is no overlap" do
      midnight_to_noon =
        Timex.Interval.new(
          from: ~N[2018-01-01 00:00:00.000],
          until: ~N[2018-01-01 12:00:00.000]
        )

      two_pm_to_four_pm =
        Timex.Interval.new(
          from: ~N[2018-01-01 14:00:00.000],
          until: ~N[2018-01-01 16:00:00.000]
        )

      assert CoachDomain.Interval.difference(midnight_to_noon, two_pm_to_four_pm) ==
               {:ok, [midnight_to_noon]}

      assert CoachDomain.Interval.difference(two_pm_to_four_pm, midnight_to_noon) ==
               {:ok, [two_pm_to_four_pm]}
    end

    test "returns an empty list when interval 2 completely covers interval 1" do
      two_to_four =
        Timex.Interval.new(
          from: ~N[2018-01-01 02:00:00.000],
          until: ~N[2018-01-01 04:00:00.000]
        )

      one_to_five =
        Timex.Interval.new(
          from: ~N[2018-01-01 01:00:00.000],
          until: ~N[2018-01-01 05:00:00.000]
        )

      assert CoachDomain.Interval.difference(two_to_four, one_to_five) == {:ok, []}
      assert CoachDomain.Interval.difference(two_to_four, two_to_four) == {:ok, []}
      assert CoachDomain.Interval.difference(one_to_five, one_to_five) == {:ok, []}
    end

    test "returns interval 1, trimmed, when interval 2 overlaps one end" do
      two_to_three =
        Timex.Interval.new(
          from: ~N[2018-01-01 02:00:00.000],
          until: ~N[2018-01-01 03:00:00.000]
        )

      two_to_four =
        Timex.Interval.new(
          from: ~N[2018-01-01 02:00:00.000],
          until: ~N[2018-01-01 04:00:00.000]
        )

      three_to_four =
        Timex.Interval.new(
          from: ~N[2018-01-01 03:00:00.000],
          until: ~N[2018-01-01 04:00:00.000]
        )

      three_to_five =
        Timex.Interval.new(
          from: ~N[2018-01-01 03:00:00.000],
          until: ~N[2018-01-01 05:00:00.000]
        )

      assert CoachDomain.Interval.difference(two_to_four, two_to_three) ==
               {:ok,
                [
                  Timex.Interval.new(
                    from: ~N[2018-01-01 03:00:00.000],
                    until: ~N[2018-01-01 04:00:00.000]
                  )
                ]}

      assert CoachDomain.Interval.difference(two_to_four, three_to_four) ==
               {:ok,
                [
                  Timex.Interval.new(
                    from: ~N[2018-01-01 02:00:00.000],
                    until: ~N[2018-01-01 03:00:00.000]
                  )
                ]}

      assert CoachDomain.Interval.difference(two_to_four, three_to_five) ==
               {:ok,
                [
                  Timex.Interval.new(
                    from: ~N[2018-01-01 02:00:00.000],
                    until: ~N[2018-01-01 03:00:00.000]
                  )
                ]}

      assert CoachDomain.Interval.difference(three_to_five, two_to_four) ==
               {:ok,
                [
                  Timex.Interval.new(
                    from: ~N[2018-01-01 04:00:00.000],
                    until: ~N[2018-01-01 05:00:00.000]
                  )
                ]}
    end

    test "splits interval 1 when interval 2 falls inside it" do
      one_to_five =
        Timex.Interval.new(
          from: ~N[2018-01-01 01:00:00.000],
          until: ~N[2018-01-01 05:00:00.000]
        )

      two_to_three =
        Timex.Interval.new(
          from: ~N[2018-01-01 02:00:00.000],
          until: ~N[2018-01-01 03:00:00.000]
        )

      assert CoachDomain.Interval.difference(one_to_five, two_to_three) ==
               {:ok,
                [
                  Timex.Interval.new(
                    from: ~N[2018-01-01 01:00:00.000],
                    until: ~N[2018-01-01 02:00:00.000]
                  ),
                  Timex.Interval.new(
                    from: ~N[2018-01-01 03:00:00.000],
                    until: ~N[2018-01-01 05:00:00.000]
                  )
                ]}
    end

    test "other than 'from' and 'until', preserves interval 1's attributes" do
      one_to_fives =
        for left_open <- [true, false],
            right_open <- [true, false],
            step <- [[seconds: 1], [minutes: 2]] do
          Timex.Interval.new(
            from: ~N[2018-01-01 01:00:00.000],
            until: ~N[2018-01-01 05:00:00.000],
            left_open: left_open,
            right_open: right_open,
            step: step
          )
        end

      midnight_to_two =
        Timex.Interval.new(
          from: ~N[2018-01-01 00:00:00.000],
          until: ~N[2018-01-01 02:00:00.000]
        )

      two_to_three =
        Timex.Interval.new(
          from: ~N[2018-01-01 02:00:00.000],
          until: ~N[2018-01-01 03:00:00.000]
        )

      four_to_six =
        Timex.Interval.new(
          from: ~N[2018-01-01 04:00:00.000],
          until: ~N[2018-01-01 06:00:00.000]
        )

      Enum.each(one_to_fives, fn one_to_five ->
        assert {:ok, [split_1, split_2]} =
                 CoachDomain.Interval.difference(one_to_five, two_to_three)

        assert split_1.left_open == one_to_five.left_open
        assert split_1.right_open == one_to_five.right_open
        assert split_1.step == one_to_five.step

        assert split_2.left_open == one_to_five.left_open
        assert split_2.right_open == one_to_five.right_open
        assert split_2.step == one_to_five.step

        assert {:ok, [left_trimmed]} =
                 CoachDomain.Interval.difference(one_to_five, midnight_to_two)

        assert left_trimmed.left_open == one_to_five.left_open
        assert left_trimmed.right_open == one_to_five.right_open
        assert left_trimmed.step == one_to_five.step

        assert {:ok, [right_trimmed]} = CoachDomain.Interval.difference(one_to_five, four_to_six)
        assert right_trimmed.right_open == one_to_five.right_open
        assert right_trimmed.left_open == one_to_five.left_open
        assert right_trimmed.step == one_to_five.step
      end)
    end
  end

  test "difference_all/2 removes one list of intervals from another" do
    midnight_to_two =
      Timex.Interval.new(
        from: ~N[2018-01-01 00:00:00.000],
        until: ~N[2018-01-01 02:00:00.000]
      )

    one_to_five =
      Timex.Interval.new(
        from: ~N[2018-01-01 01:00:00.000],
        until: ~N[2018-01-01 05:00:00.000]
      )

    one_to_three =
      Timex.Interval.new(
        from: ~N[2018-01-01 01:00:00.000],
        until: ~N[2018-01-01 03:00:00.000]
      )

    four_to_four_thirty =
      Timex.Interval.new(
        from: ~N[2018-01-01 04:00:00.000],
        until: ~N[2018-01-01 04:30:00.000]
      )

    assert CoachDomain.Interval.difference_all([midnight_to_two, one_to_five], [
             one_to_three,
             four_to_four_thirty
           ]) ==
             {:ok,
              [
                Timex.Interval.new(
                  from: ~N[2018-01-01 00:00:00.000],
                  until: ~N[2018-01-01 01:00:00.000]
                ),
                Timex.Interval.new(
                  from: ~N[2018-01-01 03:00:00.000],
                  until: ~N[2018-01-01 04:00:00.000]
                ),
                Timex.Interval.new(
                  from: ~N[2018-01-01 04:30:00.000],
                  until: ~N[2018-01-01 05:00:00.000]
                )
              ]}

    assert CoachDomain.Interval.difference_all([one_to_three], [
             one_to_five
           ]) == {:ok, []}
  end
end
