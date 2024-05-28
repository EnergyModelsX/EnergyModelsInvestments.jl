"""
    EMI.get_var_inst(m, prefix::Symbol, tm::EMG.TransmissionMode)

When the transmission mode `tm` is used as conditional input, it extracts only the variable
for the specified transmission mode.
"""
EMI.get_var_inst(m, prefix::Symbol, tm::EMG.TransmissionMode)  = m[Symbol(prefix)][tm, :]
