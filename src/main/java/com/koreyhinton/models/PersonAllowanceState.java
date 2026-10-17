package com.koreyhinton.models;

import java.math.BigDecimal;

public class PersonAllowanceState extends PersonAllowance {

    public Integer satisfiedTasks;
    public Integer lastTaskIndex;
    public Integer captureTaskIndex;

    public static class Builder {
        private final PersonAllowanceState s = new PersonAllowanceState();
        public Builder lastTaskIndex(Integer lastTaskIndex) {
            s.lastTaskIndex = lastTaskIndex;
            return this;
        }
        public Builder captureTaskIndex(Integer captureTaskIndex) {
            s.captureTaskIndex = captureTaskIndex;
            return this;
        }
        public Builder satisfiedTasks(Integer satisfiedTasks) {
            s.satisfiedTasks = satisfiedTasks;
            return this;
        }
        public Builder personName(String personName) {
            s.personName = personName;
            return this;
        }
        public Builder tasksPerWeek(Integer tasksPerWeek) {
            s.tasksPerWeek = tasksPerWeek;
            return this;
        }
        public Builder allowanceInUsd(BigDecimal allowanceInUsd) {
            s.allowanceInUsd = allowanceInUsd;
            return this;
        }
        public PersonAllowanceState build() {
            return s;
        }
    }

}
