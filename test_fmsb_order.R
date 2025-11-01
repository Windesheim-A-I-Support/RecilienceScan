# Test script to understand fmsb::radarchart dimension ordering
# This will help fix issue #70

library(fmsb)

# Create test data with distinct values to see which goes where
test_data <- data.frame(
  Dim1 = c(5, 0, 5),    # Max value - easy to spot
  Dim2 = c(5, 0, 4),
  Dim3 = c(5, 0, 3),
  Dim4 = c(5, 0, 2),
  Dim5 = c(5, 0, 1)     # Min value - easy to spot
)

# Create a PDF to see the result
pdf("test_radar_order.pdf", width=8, height=8)

# Plot with default settings
radarchart(test_data,
           axistype = 2,
           pcol = "blue",
           pfcol = scales::alpha("blue", 0.3),
           plwd = 2,
           cglcol = "grey70",
           cglty = 1,
           axislabcol = "grey40",
           caxislabels = seq(0, 5, 1),
           title = "Testing: Dim1=5(max), Dim2=4, Dim3=3, Dim4=2, Dim5=1(min)")

dev.off()

cat("PDF created: test_radar_order.pdf\n")
cat("Look for where Dim1 (value=5, the peak) appears\n")
cat("And where Dim5 (value=1, the smallest) appears\n")
cat("This will tell us the plotting order\n")
