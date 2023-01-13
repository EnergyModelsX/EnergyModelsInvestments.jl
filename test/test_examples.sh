# Loop through and run all examples in the examples folder.
cd examples
for f in *.jl; do
    echo "julia $f"
    julia $f

    # Exit with an error if the example failed.
    if [ $? -ne 0 ]; then
        echo "The example $f failed."
        exit 1
    fi
done
