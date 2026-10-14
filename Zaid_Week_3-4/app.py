import streamlit as st
import pandas as pd
import numpy as np
import matplotlib.pyplot as plt
import seaborn as sns

def load_css():

    with open("style.css") as f:

        st.markdown(
            f"<style>{f.read()}</style>",
            unsafe_allow_html=True
        )


load_css()

# ==========================
# LOAD DATA
# ==========================

df = pd.read_csv("student_data.csv")


# ==========================
# OOP CLASS
# ==========================

class Student:

    def __init__(self, dataframe):
        self.df = dataframe


    def calculate_total(self):

        self.df["Total"] = (
            self.df["Math"] +
            self.df["Science"] +
            self.df["English"]
        )

        return self.df



    def calculate_percentage(self):

        self.df["Percentage"] = (
            self.df["Total"] / 300
        ) * 100

        return self.df



    def assign_grade(self):

        def grade(x):

            if x >= 90:
                return "A+"

            elif x >= 80:
                return "A"

            elif x >= 70:
                return "B"

            elif x >= 60:
                return "C"

            else:
                return "Fail"


        self.df["Grade"] = self.df["Percentage"].apply(grade)

        return self.df



# ==========================
# OBJECT CREATION
# ==========================

student = Student(df)


df = student.calculate_total()

df = student.calculate_percentage()

df = student.assign_grade()



# ==========================
# FUNCTIONS
# ==========================


def topper(data):

    return data.loc[
        data["Percentage"].idxmax()
    ]



def department_average(data):

    return data.groupby(
        "Department"
    )["Percentage"].mean()



def grade_count(data):

    return data["Grade"].value_counts()



# ==========================
# NUMPY OPERATIONS
# ==========================


marks = np.array(
    df[
        ["Math","Science","English"]
    ]
)


average_marks = np.mean(
    marks,
    axis=1
)



# Vectorized Operation

df["Average Marks"] = average_marks



# Broadcasting

df[
    ["Math","Science","English"]
] = df[
    ["Math","Science","English"]
] + 2



# ==========================
# LIST COMPREHENSION
# ==========================


high_performers = [
    name
    for name in df["Name"]
    if name in df[
        df["Percentage"] > 85
    ]["Name"].values
]



# DICTIONARY COMPREHENSION


student_dictionary = {

    name:grade

    for name,grade

    in zip(
        df["Name"],
        df["Grade"]
    )

}



# ==========================
# STREAMLIT UI
# ==========================


st.title(
    "🎓 Student Grading System"
)


st.sidebar.header(
    "Navigation"
)


option = st.sidebar.selectbox(

    "Choose Operation",

    [
        "Student Data",
        "Topper",
        "Department Analysis",
        "Grade Distribution",
        "Visualizations"
    ]

)



# DATA DISPLAY

if option == "Student Data":

    st.subheader(
        "Student Records"
    )

    st.dataframe(df)



# TOPPER

elif option == "Topper":

    st.subheader(
        "Top Performing Student"
    )

    st.write(
        topper(df)
    )



# GROUPBY

elif option == "Department Analysis":

    st.subheader(
        "Department Average"
    )

    result = department_average(df)

    st.bar_chart(result)



# GRADE COUNT

elif option == "Grade Distribution":

    st.subheader(
        "Grades"
    )

    st.bar_chart(
        grade_count(df)
    )



# VISUALIZATION

elif option == "Visualizations":


    st.subheader(
        "Marks Distribution"
    )


    fig,ax = plt.subplots()


    sns.barplot(

        data=df,

        x="Name",

        y="Percentage",

        ax=ax

    )


    plt.xticks(
        rotation=45
    )


    st.pyplot(fig)



    st.subheader(
        "Correlation Heatmap"
    )


    fig2,ax2 = plt.subplots()


    sns.heatmap(

        df.corr(
            numeric_only=True
        ),

        annot=True,

        cmap="coolwarm",

        ax=ax2

    )


    st.pyplot(fig2)



# ==========================
# FINAL OUTPUT
# ==========================

st.success(
    "Student Analysis Completed!"
)