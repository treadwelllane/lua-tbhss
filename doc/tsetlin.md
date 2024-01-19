# How Tsetlin Machines Work

Given an input vector of K bits, a Tsetlin Machine (TM) produces a single output
bit. Multiple of these can be combined to produce an output vector. If, for
example, you have an input vector of 4096 bits and you want an output vector of
4096 bits, you would have 4096 TMs, each of which consume 4096 bits as input.

A TM first takes its input bits and duplicates them, flipping the bits of the
second half. In our example above, each of the 4096 input bits would be
duplicated and flipped so that the effective input vector becomes 8192 bits, the
first half being the original bits and the second half being the flipped bits.

This new vector of 8192 bits will then be passed to hyper-parameter N (at least
2) groups of 8192 finite state machines (FSMs). Each of these N groups of finite
state machines will produce a single bit. The bits are summed such that the bits
from the first half are considered positive and the bits from the second half
are considered negative. If there are more positive bits than negative bits, the
final output is 1, otherwise it is 0.

Each group of finite state machines is called a Tsetlin Automata Team (TAT), and
each FSM in a team is called a Tsetlin Automaton (TA).

## Tsetlin Automata Teams

Each Tsetlin Automata Team is composed of 2K Tsetlin Automata. In our ongoing
example, K is 4096 so each TAT would have 8192 TAs, half corresponding to the
original bits of the input vector and half corresponding to the flipped bits.

A single TA is an FSM of hyper-parameter M states (an even number) which can be
implemented as a simple integer that is incremented or decremented between 1 and
M. On initialization, this state is randomly set for each FSM.

The output of the TAT is an AND over all of the input bits corresponding to TAs
that are a state greater than M/2.

In other words, the output of the TAT is an AND over all of the input bits
EXCEPT those that correspond to an FSM with a state less than M/2.

Yet again in other words, FSMs with a state greater than M/2 are considered
"inclusion" rules, and FSMs with a state less than M/2 are considered
"exclusion" rules, in the sense that they determine whether an input bit is
included or excluded in the AND.

## Training

Recall that a TM takes as input a vector of K bits, and produces a single bit as
output. Recall that a TM is composed of hyper-parameter N groups of TATs, of
which half produce output bits that are considered positive and half produce
output bits that are considered negative.

Training occurs immediately after calculating an output bit for a particular
input vector. Feedback is divided into two types:

- Type I: Applied when expected output and actual output are consistent.
- Type II: Applied when expected output and actual output are inconsistent.

Additionally, feedback is limited by two hyper-parameters: T(hreshold) and
S(ensitivity). These parameters both must be greater than or equal to 1 and are
defined in the following sections.

### Type I Feedback

Only applied to TATs where the following conditions are true:

  - Condition 1:
    - Expected output of TM is 1
    - rand(0, 1) < (T - clamp(sum of the TATs negative and positive bits)) / 2T

  - Condition 2:
    - Expected output of TM is 0
    - rand(0, 1) < (T + clamp(sum of the TATs negative and positive bits)) / 2T

  - Note:
    - clamp(...) ensures the argument is between -T and T

Cases:

  - Case 1: Reinforce the correct inclusion of 1 by incrementing
    - Expected output of TM is 1
    - Actual output of TM is 1
    - TA belongs to a TAT with output bits considered positive
    - TA is associated with an input bit of 1
    - TA state is greater than M/2
    - rand(0, 1) < (S - 1) / S

  - Case 2: Reinforce the correct exclusion of 0 by decrementing
    - Expected output of TM is 1
    - Actual output of TM is 1
    - TA belongs to a TAT with output bits considered positive
    - TA is associated with an input bit of 0
    - TA state is less than M/2
    - rand(0, 1) < (1 / S)

  - Case 3: Correct the incorrect exclusion of 1 by incrementing
    - Expected output of TM is 1
    - Actual output of TM is 1
    - TA belongs to a TAT with output bits considered positive
    - TA is associated with an input bit of 1
    - TA state is less than M/2
    - rand(0, 1) < (S - 1) / S

  - Case 4: Adjust toward exclusion
    - Expected output of TM is 0
    - Actual output of TM is 0
    - TA belongs to a TAT with output bits considered negative
    - TA state is greater than M/2
    - rand(0, 1) < (1 / S)

  - Case 5: Adjust toward inclusion
    - Expected output of TM is 0
    - Actual output of TM is 0
    - TA belongs to a TAT with output bits considered negative
    - TA state is less than M/2
    - rand(0, 1) < (1 / S)

### Type II Feedback

Only applied to TATs where the following conditions are true:

  - Condition 1:
    - Expected output of TM is 1
    - rand(0, 1) < (T + clamp(sum of the TATs negative and positive bits)) / 2T

  - Condition 2:
    - Expected output of TM is 0
    - rand(0, 1) < (T - clamp(sum of the TATs negative and positive bits)) / 2T

  - Note:
    - clamp(...) ensures the argument is between -T and T

Cases:

  - Case 1: Correct the incorrect exclusion of 0
    - Expected output of TM is 0
    - Actual output of TM is 1
    - TA belongs to a TAT with output bits considered positive
    - TA is associated with an input bit of 0
    - TA state is less than M/2

# Open Items

- Why in "Training: Type I: Case 4," do we always adjust towards exclusion
  regardless of the input bit? Should we only be adjusting towards exclusion if
  the input bit is 0 (thus influencing the TAT not to vote when it should)?
  - Is this just the underlying logic informing the "bouncing between exclude
    and exclude" seen in examples?

- What is meant in the "Boosting of True Positive Feedback" part of section
  3.3.3? Instead of using the (S - 1) / S and (1 / S) we use 1 and 0?
