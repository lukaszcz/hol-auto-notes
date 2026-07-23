open HolKernel

val timed_cases_api :
    clasetStep.timed_rule_sequence -> clasetStep.timed_rule_pull =
  clasetStep.timed_rule_cases

val timed_current_api :
    clasetStep.timed_rule_sequence ->
      clasetStep.measured_rule_observation option =
  clasetStep.timed_rule_current

val timed_statistics_api :
    clasetStep.timed_rule_sequence ->
      clasetStep.timed_rule_statistics =
  clasetStep.timed_rule_statistics
